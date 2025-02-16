#!/usr/bin/env bash
if [ -z "$DOCKER_REPO" ]; then
 echo "DOCKER_REPO Not set"
 exit 1
fi

timestamp=`date +%s`
docker buildx build \
  --no-cache \
  --platform linux/amd64 \
  --target=chia_node \
  . -t $DOCKER_REPO/helm_chia_nodes:build_${timestamp} \
  -t $DOCKER_REPO/helm_chia_nodes:latest \
  --push