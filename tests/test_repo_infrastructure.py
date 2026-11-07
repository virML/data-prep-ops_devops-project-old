from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def test_security_tools_present_in_jenkins():
    pipeline = (ROOT / "Jenkinsfile").read_text()
    assert "SonarQube" in pipeline
    assert "Trivy" in pipeline
    assert "OWASP ZAP" in pipeline


def test_kubernetes_security_configured():
    text = (ROOT / "k8s/frontend-blue.yaml").read_text()
    assert "runAsNonRoot: true" in text
    assert "readOnlyRootFilesystem: true" in text
    assert "serviceAccountName: dataprepops-frontend" in text


def test_control_ssh_only():
    text = (ROOT / "terraform/main.tf").read_text()
    assert "admin_ssh" in text
    assert 'from_port = 22' in text
    assert "for_each          = local.ports" not in text
