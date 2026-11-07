#!/usr/bin/env bash
# Run on EC2 control as ubuntu. Demonstrates scoped Kubernetes permissions.
set -euo pipefail
kubectl_cmd=(sudo -u jenkins -H kubectl -n dataprepops)
"${kubectl_cmd[@]}" get serviceaccount dataprepops-frontend
"${kubectl_cmd[@]}" get role,rolebinding
# This is a synthetic classroom demo Secret, never a real API key.
if ! "${kubectl_cmd[@]}" get secret dummy-classroom-secret >/dev/null 2>&1; then
  token="$(openssl rand -hex 12)"
  "${kubectl_cmd[@]}" create secret generic dummy-classroom-secret --from-literal=demo-token="$token" >/dev/null
fi
principal='system:serviceaccount:dataprepops:dataprepops-frontend'
echo 'Expected yes for listing pods:'
"${kubectl_cmd[@]}" auth can-i list pods --as="$principal"
echo 'Expected no for reading Secrets:'
"${kubectl_cmd[@]}" auth can-i get secrets --as="$principal"
echo 'The dummy Secret is for the RBAC viva only, not an application credential.'
