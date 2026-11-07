"""FastAPI security behaviours; no AWS network calls required."""
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("DATAPREPOPS_API_KEY", "demo-test-secret")
    return TestClient(app)


def test_missing_token_denied(client):
    assert client.get("/api/jobs/" + "a" * 32).status_code == 401


def test_wrong_token_denied(client):
    assert client.post("/api/jobs", headers={"X-Demo-API-Key": "invalid"}).status_code == 401


def test_health_is_public_and_has_security_headers(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.headers["X-Content-Type-Options"] == "nosniff"
    assert r.headers["X-Frame-Options"] == "DENY"


def test_filename_and_payload_validation(client):
    h = {"X-Demo-API-Key": "demo-test-secret"}
    assert client.post("/api/jobs", headers=h, files={"file": ("wrong.txt", b"a,b\n1,2")}).status_code == 400
    assert client.post("/api/jobs", headers=h, files={"file": ("test.csv", b"a\x00,b\n1,2")}).status_code == 400
    assert client.post("/api/jobs", headers=h, files={"file": ("test.csv", b"a,b\n1,\xff")}).status_code == 400


def test_invalid_job_id_rejected_before_aws(client):
    r = client.get("/api/jobs/not-valid", headers={"X-Demo-API-Key": "demo-test-secret"})
    assert r.status_code == 400


def test_cors_not_wildcard(client):
    r = client.options("/api/jobs", headers={"Origin": "https://attacker.example", "Access-Control-Request-Method": "POST"})
    assert r.headers.get("access-control-allow-origin") != "*"
    assert r.headers.get("access-control-allow-origin") != "https://attacker.example"


def test_metrics_count_unauthorized(client):
    client.get("/api/jobs/" + "a" * 32)
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "dataprepops_http_requests_total" in r.text
