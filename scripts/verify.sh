#!/usr/bin/env bash
set -euo pipefail
set -a; . /etc/dataprepops.env; set +a
echo '--- API health ---'; curl -fsS http://127.0.0.1:8082/healthz; echo
echo '--- API auth negative test ---'; curl -s -o /dev/null -w 'Expected HTTP 401: %{http_code}\n' http://127.0.0.1:8082/api/jobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
echo '--- Kubernetes Blue-Green ---'; sudo -u jenkins -H kubectl -n dataprepops get deployments,pods,svc -o wide
echo '--- VLE9 RBAC ---'; sudo -u jenkins -H kubectl -n dataprepops auth can-i get secrets --as=system:serviceaccount:dataprepops:dataprepops-frontend
echo '--- Worker SQS backlog ---'; aws sqs get-queue-attributes --region "$AWS_REGION" --queue-url "$SQS_QUEUE_URL" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
echo '--- Docker processes ---'; docker ps --format 'table {{.Names}}\t{{.Status}}'
echo '--- Monitoring ---'; curl -fsS http://127.0.0.1:9090/-/healthy || true
