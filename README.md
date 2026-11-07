# DataPrepOps v2 — Cloud, DevOps & DevSecOps Project

**Project:** Automated CSV cleaning before ML training, with AWS, Terraform, Ansible, Jenkins, Docker, Kubernetes, monitoring, security scanning and autoscaling.

**Status:** 19 Python tests and shell/YAML static checks passed in the authoring environment. This repository has **not** been deployed to your AWS account. Terraform provider validation, Jenkins, Docker builds, SonarQube, Trivy, OWASP ZAP, Kubernetes, AWS scaling and the complete end-to-end demonstration require actual execution in your environment. A green CI badge does not prove cloud deployment.

**Start here:** Read `START_HERE.md` before running any cloud commands.

**Use synthetic/public CSVs only.** This is a **classroom** system; it is **not** a production-ready PHI/clinical platform. The exported spreadsheet is protected against formula-like strings, but data-preparation choices still require domain expertise.

## 1. What the application does (four modules)

1. **Upload & profiling:** submit a UTF-8 CSV (up to 5 MiB); the API stores it in private S3 and queues an SQS job.
2. **Cleaning:** background Docker workers remove exact duplicates, impute missing numeric values with medians and categorical values with modes, and count outliers without deleting them.
3. **Quality report:** job-specific before/after counts, quality score and imputation methods.
4. **Export & history:** poll job ID status and download a cleaned CSV/JSON report.

The program does not train an ML model. `app/cleaning.py` contains the logic, `app/main.py` the API, `worker/worker.py` the SQS worker, and `frontend/index.html` the browser UI.

## 2. Required course concepts: where they are implemented

| Requirement | Actual file/tool and proof |
|---|---|
| Git/GitHub/branching | this repository, `.github/workflows/python-tests.yml`, Pull Request demo |
| Terraform / IaC | `terraform/*.tf`, `terraform/templates/worker-userdata.sh.tftpl`, `terraform plan/apply` |
| AWS, VPC, networking | 2 public subnets in one VPC, control instance plus 2 ASG workers, restricted security groups |
| IAM / S3 / SQS / ECR | least-privilege instance roles, private encrypted S3, queue and worker image registry |
| Linux, SSH and Ansible | `scripts/setup-control.sh`, `ansible/setup.yml`, `scripts/ssh-control.sh` |
| Docker | three non-root Dockerfiles in `docker/` |
| Jenkins CI/CD / Maven | `Jenkinsfile`, `java-validator/pom.xml` |
| Kubernetes / Blue-Green | `k8s/*.yaml`, `scripts/bootstrap-blue.sh`, Jenkins approval, `scripts/rollback-blue.sh` |
| Prometheus / Grafana / Alertmanager | `monitoring/`, `scripts/start-monitoring.sh` and `scripts/security/alert-demo.sh` |
| AWS CloudWatch alarms & EC2 Auto Scaling | `terraform/main.tf` alarm, step scaling and ASG; `scripts/demo-load.py` |
| VLE-9: SonarQube SAST | `scripts/security/sonarqube-scan.sh`; gated by `check-sonar-gate.py` |
| VLE-9: Trivy | `scripts/security/trivy-scan.sh`, archived per-image reports |
| VLE-9: OWASP ZAP DAST | `scripts/security/zap-baseline.sh` (passive baseline, report) |
| VLE-9: API security | API key checked with constant-time comparison, input restrictions, CORS restriction, tests |
| VLE-9: Kubernetes security | non-root, read-only Pod filesystems, RBAC, demo Secret, no service-account token mount |
| Docker Swarm, Gradle, Artifactory (theory syllabus) | *Not part of the running deployment*. Explain as alternatives to Kubernetes/Maven/ECR; no misleading claims. |

## 3. AWS architecture and important limitations

```
Your Mac (SSH encrypted tunnels on port 22)
  ↕
AWS VPC (10.42.0.0/16; two public subnets)
  ├─ EC2 control (Ubuntu): Jenkins + Docker + Minikube
  │    ├─ Kubernetes Blue/Green frontend (2 replicas per color)
  │    ├─ FastAPI Docker container (localhost:8082)
  │    ├─ SonarQube, Prometheus, Grafana, Alertmanager
  │    └─ CI builds/pushes worker Docker image to ECR
  └─ EC2 Auto Scaling Group (desired/min=2; max=3)
       ├─ Worker instance #1 → SQS → S3
       └─ Worker instance #2 → SQS → S3
  Shared managed services: S3 / SQS (+DLQ) / ECR / CloudWatch / SNS
```

Three EC2 instances normally; four during scale-out. A single Minikube control host is **not** a three-node Kubernetes cluster. Each worker is a distinct EC2 instance, running a Docker processing container. Worker **instances have public IPs solely for internet egress in this cost-conscious lab, but their security group has no inbound rules**. A production design would use private subnets, VPC endpoints/NAT, TLS ingress, managed identity/secrets, more isolation and HA. The Jenkins/Docker group is root-equivalent: **lab use only**.

**Cost warning:** three running EC2 instances, EBS, internet-facing IPv4, storage, monitoring and data transfer can incur charges. Do not assume Free Tier eligibility. Set AWS Budgets notifications before provisioning. Deploy for the demonstration, then destroy promptly. Check the supervisor's rule about separate accounts for group members: this Terraform plan creates three EC2 instances **in one AWS account**, so use it only for an individual project or with explicit supervisor approval.

## 4. Before AWS: run local tests

On your Mac/Linux machine, after cloning the repository:

```bash
cd dataprepops       # if using the extracted ZIP; otherwise cd into your cloned repository
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements-dev.txt
python3 -m pytest -q              # expected in this version: 19 passed
```

You also need: AWS CLI v2; Terraform >= 1.5; Ansible; Git; Python 3.12+; a working AWS account, an existing EC2 SSH key pair **in the chosen region**, and a permitted EC2 instance type. `terraform fmt -check` and `terraform validate` should be run on your computer: the authoring environment did not contain the Terraform binary. On Apple Silicon, AWS control instance remains `x86_64`; the local Mac can run Terraform/Ansible normally.

## 5. Configure AWS (on Mac)

```bash
aws sts get-caller-identity
aws configure get region
MY_IP="$(curl -4fsS https://checkip.amazonaws.com | tr -d '\r\n')"
echo "Use admin_cidr = \"$MY_IP/32\" in terraform.tfvars"
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
- Set `aws_region` (example `ap-south-1`, Mumbai).
- Set `key_name` to the **AWS EC2 key-pair name**, not the `.pem` filename.
- Set `admin_cidr` to the output above with `/32`; if your ISP IP changes, update this field and re-apply Terraform.
- Confirm AWS account allows `control_instance_type` (`m7i-flex.large`, 8 GiB) and `worker_instance_type` (`t3.micro`, 1 GiB). **A 16-GiB control server might be necessary for SonarQube and Kubernetes under load.** Check rates and quota before committing.
- Optional `alert_email` sends SNS confirmation email and queue-alarm notices.

The file `terraform.tfvars` is gitignored. Never commit `.pem`, AWS keys, Jenkins credentials, or Terraform state.

```bash
terraform -chdir=terraform fmt
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan
# Inspect proposed resources/charges before applying:
terraform -chdir=terraform apply
terraform -chdir=terraform output
```

**Important:** Terraform creates the two worker EC2 instances **before** the worker Docker image is published. Their bootstrap services retry ECR pulls, which is intentional; they should begin processing after step 8 pushes the first image. Check instance console/cloud-init logs if they stay idle.

## 6. Configure the control server using Ansible (on Mac)

```bash
export SSH_KEY="$HOME/Desktop/terraform-vpc/my-key.pem"  # change path if needed
chmod 400 "$SSH_KEY"
bash scripts/setup-control.sh
```

This Ansible playbook installs Ubuntu dependencies, Docker, Java, Maven, Jenkins, AWS CLI, kubectl and Minikube; configures the control environment in `/etc/dataprepops.env`; registers a restricted frontend port-forward service; and starts Minikube as Jenkins user. **Jenkins should use GitHub as its source of code**, not a manually uploaded ZIP on EC2.

Ansible can be memory-intensive and Minikube may fail on small instances. If that occurs, inspect logs and increase the control instance memory **after reviewing charges** rather than silently weakening the Kubernetes tests.

## 7. Open the private web consoles via SSH tunnels

On your Mac, in a second Terminal tab (keep it running):

```bash
export SSH_KEY="$HOME/Desktop/terraform-vpc/my-key.pem"
bash scripts/ssh-control.sh
```

This forwards **localhost on your Mac** to the EC2 ports. There is **no public inbound access** to Jenkins/API/Grafana/SonarQube through the AWS security group.

| URL on your Mac | Service |
|---|---|
| http://localhost:8081 | DataPrepOps Blue/Green UI |
| http://localhost:8082/docs | FastAPI docs (API-key protected jobs) |
| http://localhost:8080 | Jenkins |
| http://localhost:9000 | SonarQube |
| http://localhost:3000 | Grafana |
| http://localhost:9090/targets | Prometheus |
| http://localhost:9090/alerts | Prometheus alerts |
| http://localhost:9093 | Alertmanager |

If ports are already occupied on your Mac, close the conflicting service or adjust the *local* `-L` side in `scripts/ssh-control.sh`. Private dashboard access by SSH tunnels is a demo security measure, not a replacement for production HTTPS.

## 8. Bootstrap code and data processing (on control EC2)

In a new Mac terminal:

```bash
export SSH_KEY="$HOME/Desktop/terraform-vpc/my-key.pem"
ssh -i "$SSH_KEY" "ubuntu@$(terraform -chdir=terraform output -raw control_public_ip)"
```

On EC2, clone the repo you uploaded to GitHub:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_NEW_REPOSITORY.git
cd YOUR_NEW_REPOSITORY
```

Create a **private demonstration API key** on EC2 (do not commit it; you will add the same value as a Jenkins secret-text credential in step 10):

```bash
export DATAPREPOPS_API_KEY="$(openssl rand -hex 16)"
# To copy the value privately, run the following, then hide this terminal from screenshots:
printf '%s\n' "$DATAPREPOPS_API_KEY"
```

Build and push the initial worker image to ECR; start the API, then Blue UI:

```bash
bash scripts/publish-worker.sh
bash scripts/start-api.sh
bash scripts/bootstrap-blue.sh
bash scripts/verify.sh
```

The worker ASG instances should retry `docker pull` automatically. If not, inspect EC2 cloud-init and systemd `dataprepops-worker-bootstrap.service` logs. A worker created **before** a new image was published does not automatically upgrade to later image versions.

Open `http://localhost:8081` through your **Mac tunnel**, enter the API key, and upload `sample_data/dirty_sample.csv`. The SQS worker should return a completed result; download the cleaned CSV and compare its rows with the sample expected output. The UI key is held in page memory and must be re-entered after refresh.

## 9. Start monitoring and alerting (on EC2)

```bash
export GRAFANA_ADMIN_PASSWORD="$(openssl rand -hex 16)"
# Save this separately and privately before continuing.
bash scripts/start-monitoring.sh
```

Open Grafana `http://localhost:3000`, sign in as `admin` using that password. The provisioned `DataPrepOps API Overview` dashboard should show target up=1 and requests over time. Prometheus at `http://localhost:9090/targets` should show `dataprepops-api` UP.

Show unauthorized-access alert rules:

```bash
bash scripts/security/alert-demo.sh
```

Wait for an evaluation cycle and view `/alerts`. You can additionally demonstrate `DataPrepOpsAPIDown`:

```bash
docker stop dataprepops-api
# Wait ~60–90 seconds; observe alert state.
docker start dataprepops-api
```

The Alertmanager configuration routes alerts to a classroom receiver with **no external contact**; AWS CloudWatch + SNS provides email when `alert_email` is configured and SNS subscription confirmed. Do not claim Slack/email from Alertmanager.

## 10. SonarQube and Jenkins setup (on EC2 + browser)

Start SonarQube on the control EC2:

```bash
bash scripts/security/start-sonarqube.sh
```

Wait until `http://localhost:9000` loads (via the Mac tunnel). Complete SonarQube first-run setup and change default credentials. Create a project with key **`dataprepops`**, and create a token authorized to scan that project. Keep the token private. On 8-GiB EC2, SonarQube and Minikube/monitoring can contend for memory; close nonessential dashboards/containers when not demonstrating them or select an appropriately sized host.

Open Jenkins `http://localhost:8080` and finish first-run setup using the unlock password on EC2:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Install suggested plugins (including Pipeline/Git); manually install `Credentials Binding` if missing. In **Manage Jenkins → Credentials**, add **two Secret text credentials**:

1. ID **`dataprepops-sonar-token`**, secret = SonarQube analysis token.
2. ID **`dataprepops-api-key`**, secret = the same demo API key used in step 8.

Create **New Item → Pipeline**, name `DataPrepOps-Secure-CI`. Choose **Pipeline script from SCM**, Git repo `https://github.com/YOUR_USERNAME/YOUR_NEW_REPOSITORY.git`, branch `*/main`, script path `Jenkinsfile`. No GitHub credentials are required if the repository remains public. **Build Now** after the preparatory steps are complete. If your public repository does not yet have all the files, upload the ZIP contents before starting the build.

The pipeline runs tests → Maven validation → **SonarQube + quality gate** → Docker builds → **Trivy vulnerability reports** → ECR worker publish → API deploy → Green Kubernetes Pods → **ZAP passive DAST** → approval → switch to Green. ZAP warnings remain visible, Trivy findings are reported rather than treated as fixed. A failing Sonar quality gate stops deployment.

Check the stages in `Jenkinsfile` and inspect Jenkins Console Output if any stage fails. Note: `sonarsource/sonar-scanner-cli:latest`, `sonarqube:community` and the ZAP stable container may change over time; re-check if network/download or compatibility errors arise.

## 11. Security proof and Blue-Green rollback (on EC2)

```bash
bash scripts/security/k8s-rbac-demo.sh
sudo -u jenkins -H kubectl -n dataprepops get deploy,pods,svc
sudo -u jenkins -H kubectl -n dataprepops get svc dataprepops-frontend -o jsonpath='{.spec.selector.color}'; echo
curl -fsS http://127.0.0.1:8081/version.js
```

RBAC should report **yes for listing Pods and no for reading Secrets** for the frontend service account. The synthetic Kubernetes Secret is for a **permission demonstration**, not the real API credential. Frontend Pods have non-root IDs, a read-only root filesystem, dropped capabilities, and disabled automatic service-account token mounts.

After Jenkins switches to Green, confirm the browser label shows `GREEN`. To roll back:

```bash
bash scripts/rollback-blue.sh
```

**Why restart the port-forward?** `kubectl port-forward service/...` attaches to a chosen Pod when started. When a Service selector switches color, an existing port-forward may still target the original Pod. The pipeline and rollback script restart the dedicated forwarding service to demonstrate the actual new release.

## 12. Test CloudWatch and EC2 Auto Scaling (EC2 control + AWS console)

Generate **synthetic** queue workload:

```bash
set -a; . /etc/dataprepops.env; set +a
/opt/dataprepops-demo-venv/bin/python scripts/demo-load.py --jobs 100 --seconds 30
```

View **AWS Console → SQS → project job queue**, **CloudWatch → Alarms**, **EC2 → Auto Scaling Groups → Activity/Instances**. The intended configuration scales workers **2 → 3 → 2**, subject to CloudWatch metric periods, EC2 startup time, quota, and actual queue load. The script does not guarantee the queue will remain above the threshold long enough to trigger scaling. For evidence, capture actual scaling history and do not label a static Desired Capacity setting as proof of automatic scaling.

For an update to worker images, Jenkins publishes a new `:latest` ECR image for **new** workers. Running workers continue their previous image until replaced. If you choose to refresh the ASG manually in AWS console, document that as a separate action, not automatic rollout.

## 13. Final validation + professor viva

See **`DEMO_GUIDE.md`** for exact 12-screen evidence checklist, a 5-minute demo sequence, explanation of each tool, failure/rollback, security interpretations and concise viva answers. See **`ARCHITECTURE.md`** for data and deployment diagrams.

## 14. Teardown: stop AWS billing

After evidence and screenshots are saved to your own machine:

```bash
# On your local Mac in repo root, after double-checking AWS account and region:
terraform -chdir=terraform plan -destroy
terraform -chdir=terraform destroy
```

`force_destroy=true` means the demo S3 bucket's uploaded data will be **permanently deleted**. Verify that only the intended project resources are in this state. **Do not** delete unrelated resources or shared resources. Then verify EC2 instance list, EBS volumes/snapshots, load balancers, public IPv4, S3, ECR and billing/cost explorer for any remaining chargeable resources. AWS billing may lag; a terminated EC2 instance is not sufficient proof that all associated costs are gone.

## 15. Project honesty / limitations

- This ZIP is a **code + runbook artifact**, not a deployment report. It cannot truthfully contain Jenkins/Auto Scaling success screenshots from your account.
- The pipeline's Trivy vulnerability scan is **report-only** (exit code 0). Review findings manually. The SonarQube quality gate is enforced.
- ZAP baseline is **passive** and does not prove the absence of exploitable security weaknesses.
- Secrets inside Jenkins/Docker and local-demo browser inputs are for classroom use; do not upload actual confidential CSV data.
- The Auto Scaling Group manages EC2 workers, while Minikube only orchestrates the frontend Pods. They are **not** a unified distributed Kubernetes cluster.
- Docker Swarm, Gradle and Artifactory are syllabus alternatives, not deployed services. Do not claim every named technology in the entire syllabus is running.
- Security controls do not establish HIPAA, GDPR or any formal compliance certification.

