#!/usr/bin/env bash
# Run on EC2 control. Web consoles available only through encrypted SSH forwarding.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GRAFANA_ADMIN_PASSWORD:?Set GRAFANA_ADMIN_PASSWORD (never commit it)}"
docker rm -f dataprepops-prometheus dataprepops-grafana dataprepops-alertmanager >/dev/null 2>&1 || true
mkdir -p reports
docker volume create dataprepops-prometheus-data >/dev/null
# Prometheus runs as uid 65534 in the official image.
docker run --rm -v dataprepops-prometheus-data:/prometheus alpine:3.22 chown 65534:65534 /prometheus >/dev/null
docker run -d --restart unless-stopped --network host   --name dataprepops-prometheus   -v "$PWD/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro"   -v "$PWD/monitoring/alerts.yml:/etc/prometheus/alerts.yml:ro"   -v dataprepops-prometheus-data:/prometheus   prom/prometheus:v3.5.0   --config.file=/etc/prometheus/prometheus.yml   --web.listen-address=127.0.0.1:9090   --storage.tsdb.path=/prometheus >/dev/null
docker run -d --restart unless-stopped --network host   --name dataprepops-alertmanager   -v "$PWD/monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro"   prom/alertmanager:v0.28.1   --config.file=/etc/alertmanager/alertmanager.yml   --web.listen-address=127.0.0.1:9093 >/dev/null
docker volume create dataprepops-grafana-storage >/dev/null
docker run -d --restart unless-stopped --network host   --name dataprepops-grafana   -e GF_SERVER_HTTP_ADDR=127.0.0.1   -e GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"   -v "$PWD/monitoring/grafana/provisioning:/etc/grafana/provisioning:ro"   -v "$PWD/monitoring/grafana/dashboard.json:/etc/grafana/dashboards/data.json:ro"   -v dataprepops-grafana-storage:/var/lib/grafana   grafana/grafana:12.1.0 >/dev/null
printf 'Monitoring on localhost: Grafana 3000, Prometheus 9090, Alertmanager 9093.\n'
