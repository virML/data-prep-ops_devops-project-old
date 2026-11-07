#!/usr/bin/env bash
set -euo pipefail
# Run on Mac/Linux laptop with Terraform and Ansible installed.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SSH_KEY:?Set SSH_KEY to your existing .pem path first}"
TF=(terraform "-chdir=$ROOT/terraform")
ip="$("${TF[@]}" output -raw control_public_ip)"
# Pull configured region from terraform.tfvars, without relying on it being in outputs.
region="$("${TF[@]}" output -raw aws_region)"
bucket="$("${TF[@]}" output -raw s3_bucket)"
queue="$("${TF[@]}" output -raw sqs_queue_url)"
ecr="$("${TF[@]}" output -raw ecr_worker_uri)"
cat > "$ROOT/ansible/inventory.ini" <<EOF
[control]
$ip ansible_user=ubuntu
EOF
ansible-playbook -i "$ROOT/ansible/inventory.ini" "$ROOT/ansible/setup.yml" \
  --private-key "$SSH_KEY" \
  -e "aws_region=$region" -e "s3_bucket=$bucket" -e "sqs_queue_url=$queue" -e "ecr_worker_uri=$ecr"
printf '\nControl ready. SSH: ssh -i "%s" ubuntu@%s\n' "$SSH_KEY" "$ip"
