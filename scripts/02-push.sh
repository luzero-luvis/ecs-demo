#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ecr-demo-app}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Get repo URI from Terraform output — single source of truth
REPO_URI=$(cd "$TERRAFORM_DIR" && terraform output -raw repository_url 2>/dev/null || true)

# Validate it looks like an ECR URI
if [[ -z "$REPO_URI" || "$REPO_URI" != *".dkr.ecr."* ]]; then
  echo "ERROR: Terraform has not been applied yet or has no outputs."
  echo ""
  echo "Run this first:"
  echo "  cd terraform && terraform init && terraform apply"
  exit 1
fi

# Derive region from the repo URI  (format: <account>.dkr.ecr.<region>.amazonaws.com/<name>)
AWS_REGION=$(echo "$REPO_URI" | cut -d. -f4)
REGISTRY=$(echo "$REPO_URI" | cut -d/ -f1)
TIMESTAMP_TAG=$(date -u +%Y%m%d%H%M%S)

echo "Pushing to ECR: $REPO_URI"
echo ""

if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &>/dev/null; then
  echo "ERROR: Local image '$IMAGE_NAME:$IMAGE_TAG' not found. Run 01-build.sh first."
  exit 1
fi

# Authenticate
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$REGISTRY"

# Tag and push
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REPO_URI:$IMAGE_TAG"
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REPO_URI:$TIMESTAMP_TAG"

docker push "$REPO_URI:$IMAGE_TAG"
docker push "$REPO_URI:$TIMESTAMP_TAG"

echo ""
echo "Pushed:"
echo "  $REPO_URI:$IMAGE_TAG"
echo "  $REPO_URI:$TIMESTAMP_TAG"
echo ""
echo "ECS will pull the new image on the next task restart."
echo "To force a redeployment:"
echo "  cd terraform && terraform apply"
