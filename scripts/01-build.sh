#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ecr-demo-app}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
APP_VERSION="${APP_VERSION:-1.0.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "Building image: $IMAGE_NAME:$IMAGE_TAG"
echo ""

docker build \
  --tag "$IMAGE_NAME:$IMAGE_TAG" \
  --build-arg APP_VERSION="$APP_VERSION" \
  --label "version=$APP_VERSION" \
  --label "built-at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  .

echo ""
echo "Build complete: $IMAGE_NAME:$IMAGE_TAG"
docker images "$IMAGE_NAME"
