from fastapi.testclient import TestClient
from app.main import app


def test_healthz_without_aws_credentials():
    response = TestClient(app).get('/healthz')
    assert response.status_code == 200
    assert response.json()['status'] == 'ok'


def test_reject_invalid_job_identifier(monkeypatch):
    monkeypatch.setenv('DATAPREPOPS_API_KEY', 'test-key')
    response = TestClient(app).get('/api/jobs/not-an-id', headers={'X-Demo-API-Key': 'test-key'})
    assert response.status_code == 400
