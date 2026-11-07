# Security — scope and verified versus unverified controls

This project implements **classroom DevSecOps controls** and deliberately processes only synthetic or public CSVs. It is not production security certification.

## Source security (SAST)

`Jenkinsfile` calls `scripts/security/sonarqube-scan.sh`, which uses SonarQube Community scanning and `check-sonar-gate.py`. A failing SonarQube quality gate prevents later deployment. The SonarQube token is stored in Jenkins Credentials as `dataprepops-sonar-token`. The project must be configured in SonarQube first.

## Container security

All three Dockerfiles use UID/GID `10001:10001`; Jenkins checks image metadata. Trivy scans API, worker and frontend images. **Trivy is report-only**, emitting per-image reports in `reports/`. A successful scan stage means the scan ran, not that the image has zero vulnerabilities. Review reports, update base images and dependencies, then re-scan.

## Kubernetes security

Frontend Pods run with `runAsNonRoot`, `readOnlyRootFilesystem`, dropped Linux capabilities, `allowPrivilegeEscalation=false`, `seccompProfile: RuntimeDefault`, and `automountServiceAccountToken=false`. An RBAC demo role allows Pod reads, not Secret reads; a dummy Secret is created **only for demonstration**. Production application credentials are not automatically deployed to Kubernetes because FastAPI is hosted in a separate Docker container on EC2.

## Dynamic security (DAST)

ZAP baseline tests `http://127.0.0.1:8082/docs` over a Linux EC2 host network and archives HTML and JSON reports. It is a **passive baseline**, does not perform aggressive active attacks, and ignores warning-level exit codes. Do not claim zero vulnerabilities or penetration-test certification from a PASS count.

## API and network security

The API requires a runtime `X-Demo-API-Key` for all job, status, report and download endpoints. It validates file sizes, UTF-8, job IDs and filenames, emits response hardening headers, and restricts CORS to local-tunneled frontend origins. CSV exports prefix spreadsheet-formula-like strings to reduce spreadsheet injection exposure. Health and metrics endpoints are unauthenticated because they are accessible only over private loopback/SSH-tunneled ports in this demo.

Terraform exposes only SSH port 22 from the student's CIDR on the control instance, none on worker security groups. The system uses IAM instance profiles rather than AWS access keys; S3 is private, at-rest encrypted and requires TLS; EC2 EBS volumes are encrypted; IMDSv2 is required. Worker EC2 public IPv4 for egress, Jenkins Docker-group access, demo API key exposure in Docker environment and a single control server are **lab trade-offs**, not production recommendations.

## Data, secrets and what never goes to GitHub

Never commit or upload `.pem`, `.env`, Terraform state, `terraform.tfvars`, service-account tokens, Jenkins passwords, SonarQube tokens, AWS credentials, live datasets, or generated scan reports with potentially sensitive environment info. GitHub code and tests should remain public-data-only.

## Locally verified

In the authoring environment: 19 offline Python tests passed; YAML/JSON parsing, frontend JavaScript syntax and shell script syntax checks passed. These are **not** substitutes for AWS and container execution. Jenkins quality gate, real container scanning/DAST, Kubernetes rollout, CloudWatch alarm and autoscaling remain **live verification tasks**.
