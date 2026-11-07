#!/usr/bin/env bash
# Run on Mac/Linux laptop after Terraform. Browser: http://localhost:8081
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SSH_KEY:?Export SSH_KEY pointing to the private .pem SSH key}"
ip="$(terraform -chdir="$ROOT/terraform" output -raw control_public_ip)"
exec ssh -o ExitOnForwardFailure=yes -o IdentitiesOnly=yes -i "$SSH_KEY" -N   -L 8080:127.0.0.1:8080 -L 8081:127.0.0.1:8081   -L 8082:127.0.0.1:8082 -L 3000:127.0.0.1:3000   -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093   -L 9000:127.0.0.1:9000 "ubuntu@$ip"
