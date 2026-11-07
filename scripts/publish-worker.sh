#!/usr/bin/env bash
# Run on EC2 control as ubuntu/Jenkins. First arg = local image tag.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . /etc/dataprepops.env; set +a
image="${1:-}"
tag="${2:-latest}"
registry="${ECR_WORKER_URI%%/*}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$registry"
if [ -z "$image" ]; then
  image="dataprepops-worker:manual"
  docker build -f docker/Dockerfile.worker -t "$image" .
fi
docker tag "$image" "$ECR_WORKER_URI:$tag"
docker tag "$image" "$ECR_WORKER_URI:latest"
docker push "$ECR_WORKER_URI:$tag"
docker push "$ECR_WORKER_URI:latest"
echo 'Worker image published to ECR. New ASG workers pull :latest. Running workers are NOT automatically replaced.'
