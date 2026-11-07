#!/usr/bin/env bash
# Jenkins runs this against the lab API using Docker host networking on Linux.
set -euo pipefail
cd "$(dirname "$0")/../.."
curl -fsS http://127.0.0.1:8082/docs >/dev/null
mkdir -p reports
# ZAP image uses a dedicated unprivileged user; grant write access to scan report folder.
chmod a+rwx reports
docker run --rm --network host -v "$PWD/reports:/zap/wrk:rw"   ghcr.io/zaproxy/zaproxy:stable zap-baseline.py   -t http://127.0.0.1:8082/docs -m 1 -r zap-report.html -J zap-report.json -I
printf 'ZAP passive DAST report saved to reports/zap-report.html\n'
