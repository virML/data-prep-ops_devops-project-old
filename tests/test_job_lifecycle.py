"""Offline integration-style tests using fake S3 and SQS clients."""
import io
import json

from fastapi.testclient import TestClient

import app.main as main


class FakeS3:
    def __init__(self):
        self.objects = {}

    def put_object(self, *, Bucket, Key, Body, **kw):
        self.objects[(Bucket, Key)] = Body

    def get_object(self, *, Bucket, Key):
        return {"Body": io.BytesIO(self.objects[(Bucket, Key)])}


class FakeSQS:
    def __init__(self):
        self.messages = []

    def send_message(self, *, QueueUrl, MessageBody):
        self.messages.append(json.loads(MessageBody))


def test_submit_then_fetch_status(monkeypatch):
    s3, sqs = FakeS3(), FakeSQS()
    monkeypatch.setenv("DATAPREPOPS_API_KEY", "test-only")
    monkeypatch.setenv("AWS_REGION", "ap-south-1")
    monkeypatch.setenv("S3_BUCKET", "demo-bucket")
    monkeypatch.setenv("SQS_QUEUE_URL", "https://example.invalid/demo-queue")
    monkeypatch.setattr(main, "s3_client", lambda region: s3)
    monkeypatch.setattr(main.boto3, "client", lambda service, **kw: sqs if service == "sqs" else s3)
    client = TestClient(main.app)
    h = {"X-Demo-API-Key": "test-only"}
    result = client.post("/api/jobs", headers=h, files={"file": ("test.csv", b"name,age\nA,25\nB,\n", "text/csv")})
    assert result.status_code == 202
    job_id = result.json()["job_id"]
    assert sqs.messages == [{"job_id": job_id, "simulate_seconds": 0}]
    status = client.get(f"/api/jobs/{job_id}", headers=h)
    assert status.status_code == 200
    assert status.json()["state"] == "queued"
    assert s3.objects[("demo-bucket", f"jobs/{job_id}/raw.csv")].startswith(b"name,age")


def test_download_and_report_after_worker_completion(monkeypatch):
    s3 = FakeS3()
    job_id = "a" * 32
    monkeypatch.setenv("DATAPREPOPS_API_KEY", "test-only")
    monkeypatch.setenv("S3_BUCKET", "demo-bucket")
    monkeypatch.setenv("SQS_QUEUE_URL", "https://example.invalid/demo-queue")
    monkeypatch.setattr(main, "s3_client", lambda region: s3)
    s3.put_object(Bucket="demo-bucket", Key=f"jobs/{job_id}/status.json", Body=b'{"state":"complete"}')
    s3.put_object(Bucket="demo-bucket", Key=f"jobs/{job_id}/cleaned.csv", Body=b"age\n25\n")
    s3.put_object(Bucket="demo-bucket", Key=f"jobs/{job_id}/report.json", Body=b'{"cleaned_rows":1}')
    client = TestClient(main.app)
    headers = {"X-Demo-API-Key": "test-only"}
    downloaded = client.get(f"/api/jobs/{job_id}/download", headers=headers)
    assert downloaded.status_code == 200
    assert downloaded.content == b"age\n25\n"
    report = client.get(f"/api/jobs/{job_id}/report", headers=headers)
    assert report.status_code == 200
    assert report.json()["cleaned_rows"] == 1
