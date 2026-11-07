# START HERE — DataPrepOps course project

**This package is ready to upload to a new GitHub repository.** The project code is included, but the AWS and Jenkins parts still require real cloud setup and testing. The existing 19 Python tests only validate the local application and selected configuration conditions; they do **not** prove the complete cloud architecture runs.

## Upload to GitHub (first)

1. Create a **new, empty** GitHub repository (public makes Jenkins checkout easier). Do not initialize it with a README to keep first push simple.
2. Unzip `DataPrepOps_FINAL_Ready_For_GitHub.zip`. The extracted folder is `dataprepops`.
3. Upload the **contents** of `dataprepops/` to the repo root. Do not upload the ZIP as a file, and do not put the whole project under a nested `dataprepops/` folder in the repo.
4. Preserve hidden `.github/`, `.gitignore`, `.dockerignore`, `.gitattributes` files. See `UPLOAD_TO_GITHUB.md` for safer Git commands.
5. Open the repository **Actions → Python CI** and confirm its test workflow passed.

## What you must do after uploading (in order)

| Phase | On which machine / UI | Main action | Evidence |
|---|---|---|---|
| 1. Local test | Mac Terminal | Python venv + `pytest` | 19 tests pass |
| 2. AWS infrastructure | Mac Terminal + AWS Console | Configure credentials, `terraform plan` / `apply` | VPC, 1 control EC2, 2 worker EC2, alarms and ASG |
| 3. Linux provisioning | Mac Terminal | `bash scripts/setup-control.sh` (Ansible) | Ansible recap + Jenkins/Minikube installed |
| 4. Initial app deployment | EC2 Terminal | Clone **your new repository**; run worker publish, API start, Blue deploy | CSV submit, processing and download |
| 5. Monitoring | EC2 Terminal + browser via SSH | Start Prometheus/Grafana/Alertmanager, test rules | Dashboards + actual alerts |
| 6. Security + CI/CD | EC2 Terminal + Jenkins/SonarQube UI | Start SonarQube; add 2 Jenkins credentials; run pipeline | SAST, Trivy, ZAP, Green switch |
| 7. Scaling / rollback | EC2 Terminal + AWS Console | Trigger synthetic SQS load and roll back UI | ASG activity and Blue restored |
| 8. Clean up | Mac Terminal + AWS Console | `terraform destroy` after saving evidence | Project resources gone |

**Detailed commands are in `README.md` sections 4–14.** The professor demonstration and viva checklist are in `DEMO_GUIDE.md`. You should not need to write additional application code **if** cloud versions/permissions work as expected. Fixes may be required after real EC2, Terraform, Docker, and Jenkins execution; that is normal for an unprovisioned lab.

## Scope: basic application, full course-tool demonstration

Application: only upload CSV, remove duplicates/fill blanks, show quality report, download cleaned CSV. No model training, complicated frontend, or database.

Tool demonstrations: Git, Terraform, Ansible, Jenkins CI/CD, Maven mini-check, Docker, Kubernetes Blue/Green, Prometheus/Grafana, CloudWatch Auto Scaling, SonarQube, Trivy, ZAP, IAM/SSH security and Kubernetes RBAC.

Docker Swarm, Gradle and Artifactory are syllabus topics discussed as alternatives rather than deployed components. If your professor explicitly requires each of these in the project, this implementation would need a separate minimal demo.

## Two non-command tasks you must not overlook

- **AWS Console:** Verify AWS account/region/EC2 key, allowed instance types and quota, SNS subscription, ASG scaling activity and cost/budget controls. Three EC2 instances in one account are only appropriate under the supervisor's solo exception or permission.
- **Jenkins/SonarQube/browser:** Perform initial installation setup, generate a SonarQube token, create Jenkins Secret Text credentials (never commit), create the Jenkins Pipeline from your new GitHub URL, approve the Blue-Green switch, and inspect monitoring dashboards.

## Local quick test (Mac)

```bash
cd ~/Downloads/dataprepops
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest -q
```

**Cost and safety:** The Terraform design includes three EC2 instances, storage and potentially billable public IPv4 addresses; an 8 GiB control instance may be under memory pressure running Jenkins + SonarQube + Minikube + Grafana. Use synthetic CSVs only, watch costs, restrict SSH to your IP, and destroy lab resources after the demo. Trivy's scans are report-only and ZAP's baseline scan is passive, not security certification.
