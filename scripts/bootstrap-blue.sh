#!/usr/bin/env bash
# Run on control EC2 as ubuntu after Ansible, Docker and Minikube startup.
set -euo pipefail
cd "$(dirname "$0")/.."
docker build -f docker/Dockerfile.frontend --build-arg VERSION=blue -t dataprepops-frontend:blue .
sudo -u jenkins -H minikube image load dataprepops-frontend:blue
sudo -u jenkins -H kubectl apply -f k8s/namespace-rbac.yaml
sudo -u jenkins -H kubectl apply -f k8s/frontend-blue.yaml
sudo -u jenkins -H kubectl -n dataprepops rollout status deployment/dataprepops-blue --timeout=180s
sudo -u jenkins -H kubectl apply -f k8s/frontend-service.yaml
sudo -u jenkins -H kubectl -n dataprepops get deployments,pods,service -o wide
sudo systemctl enable --now dataprepops-frontend.service
curl --retry 15 --retry-delay 2 --retry-connrefused -fsS http://127.0.0.1:8081/ >/dev/null
printf 'Blue frontend ready at http://localhost:8081 via SSH tunnel\n'
