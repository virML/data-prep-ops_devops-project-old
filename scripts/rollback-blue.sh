#!/usr/bin/env bash
set -euo pipefail
sudo -u jenkins -H kubectl -n dataprepops patch service dataprepops-frontend   -p '{"spec":{"selector":{"app":"dataprepops-ui","color":"blue"}}}'
sudo -u jenkins -H kubectl -n dataprepops get svc dataprepops-frontend -o jsonpath='{.spec.selector.color}'
echo
sudo systemctl restart dataprepops-frontend.service
sleep 3
curl -fsS http://127.0.0.1:8081/version.js
