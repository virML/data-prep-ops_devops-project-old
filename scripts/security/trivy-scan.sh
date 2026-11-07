#!/usr/bin/env bash
# Report-only vulnerability scanning: never describe findings as remediated.
set -euo pipefail
cd "$(dirname "$0")/../.."
num="${1:?Pass Jenkins build number}"
mkdir -p reports
docker volume create dataprepops-trivy-cache >/dev/null
for pair in "api:dataprepops-api:build-$num" "worker:dataprepops-worker:build-$num" "frontend:dataprepops-frontend:green-$num"; do
  kind="${pair%%:*}"
  image="${pair#*:}"
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock     -v "$PWD/reports:/reports" -v dataprepops-trivy-cache:/root/.cache/     aquasec/trivy:0.76.2 image --scanners vuln --severity HIGH,CRITICAL     --exit-code 0 --format table --output "/reports/trivy-$kind.txt" "$image"
  echo "Trivy $kind findings in reports/trivy-$kind.txt"
done
