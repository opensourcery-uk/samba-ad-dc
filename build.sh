#!/bin/bash
set -euo pipefail

REGISTRY_IMAGE=$1
IMAGE_TAG=${2:-latest}

docker build --rm -t ${REGISTRY_IMAGE}:${IMAGE_TAG} .
docker push ${REGISTRY_IMAGE}:${IMAGE_TAG}
