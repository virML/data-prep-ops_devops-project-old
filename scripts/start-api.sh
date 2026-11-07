#!/usr/bin/env bash
# Replaces only DataPrepOps API container. Run via Jenkins with its credential.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . /etc/dataprepops.env; set +a
: "${DATAPREPOPS_API_KEY:?Set DATAPREPOPS_API_KEY in your shell or Jenkins credentials}"
image="${1:-}"
if [ -z "$image" ]; then
  image='dataprepops-api:manual'
  docker build -f docker/Dockerfile.api -t "$image" .
fi
docker rm -f dataprepops-api >/dev/null 2>&1 || true
docker run -d --restart unless-stopped -p 127.0.0.1:8082:8082   --name dataprepops-api   -e AWS_REGION -e S3_BUCKET -e SQS_QUEUE_URL -e UI_ORIGIN   -e DATAPREPOPS_API_KEY   "$image" >/dev/null
curl --retry 20 --retry-delay 2 --retry-connrefused -fsS http://127.0.0.1:8082/healthz
printf '\nAPI healthy through loopback port 8082\n'
