# Troubleshooting quick reference

| Symptom | Check and remedy |
|---|---|
| `terraform apply` rejected instance type | Confirm quota/Free Tier policy and regional instance eligibility; set allowed types in `terraform.tfvars` and re-plan. |
| SSH timed out | EC2 instance running, public IPv4, correct `.pem`, EC2 key pair name and `/32` admin CIDR. If your IP changed, update Terraform and apply. |
| Ansible permission denied | Use `SSH_KEY=...` pointing to the same EC2 key, `chmod 400`, and `ubuntu` SSH user. |
| Jenkins Build waiting for executor | Built-In Node online, enough memory/disk and no offline temporary-storage threshold; inspect Jenkins node page. |
| Minikube start fails or Pods crash | Check EC2 RAM/disk and Jenkins user Docker access; run `sudo -u jenkins -H minikube status`, `kubectl describe pod` and instance `free -h`/`df -h`. |
| UI blank on localhost:8081 | Keep SSH tunnel running, run `systemctl status dataprepops-frontend.service`, `sudo -u jenkins -H kubectl -n dataprepops get pods`, and `curl 127.0.0.1:8081`. |
| UI upload returns 401 | Enter the same API key stored in Jenkins credential and used when launching `dataprepops-api`. Refresh clears in-memory key. |
| SQS job stays queued | ECR image may not yet exist; run `bash scripts/publish-worker.sh`, inspect EC2 worker `journalctl -u dataprepops-worker-bootstrap.service`, check IAM/ECR/network. |
| API returns 503 | Check `/etc/dataprepops.env`, EC2 IAM role, S3/SQS names and `docker logs dataprepops-api`; verify network and S3 permissions. |
| SonarQube refuses to start | On EC2 check `docker logs dataprepops-sonarqube`, `vm.max_map_count`, RAM/disk, Java heap/ES, and port 9000. It may require a larger control instance. |
| Sonar scanner quality gate fails | Inspect SonarQube project `dataprepops` and token access. Scan fails by design if gate is not OK; fix findings rather than bypass it. |
| Trivy scanner cannot pull database | Ensure EC2 outbound internet and DNS work; retry after verifying registry access. Docker socket mount is lab-only root-equivalent access. |
| ZAP cannot write report | Ensure `reports/` is writable by the ZAP container, API `/docs` responds locally, and Docker `--network host` runs on Linux EC2 (not the Mac). |
| Service selector says Green but browser still Blue | A `kubectl port-forward` is bound to a chosen Pod; `sudo systemctl restart dataprepops-frontend.service` then check `/version.js`. |
| Grafana dashboard missing | `docker logs dataprepops-grafana`, provisioning directory mounts, Prometheus target UP, correct SSH tunnel port 3000. |
| Prometheus alert not firing | Verify `/metrics` includes the counter and time-series, send 401 requests, wait evaluation intervals; for API-down stop container and wait ~60–90 seconds. |
| SQS backlog but no scale-out | Check CloudWatch metric has datapoints, alarm threshold and evaluation periods, ASG max capacity, AWS account quotas and instance startup. It is not instantaneous. |
| `terraform destroy` fails | Review active ECR images, S3 deletion policies and lingering AWS resources; do not delete unrelated instances. Never force-delete an account-wide resource. |
