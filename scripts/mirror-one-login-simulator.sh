#!/usr/bin/env bash

set -euo pipefail

source_image="${1:?Usage: $0 ghcr.io/...@sha256:<digest> <ecr-registry> <ecr-repository>}"
ecr_registry="${2:?Usage: $0 ghcr.io/...@sha256:<digest> <ecr-registry> <ecr-repository>}"
ecr_repository="${3:?Usage: $0 ghcr.io/...@sha256:<digest> <ecr-registry> <ecr-repository>}"

if [[ ! "$source_image" =~ ^ghcr\.io/govuk-one-login/simulator@sha256:[0-9a-f]{64}$ ]]; then
  echo "Source image must be the pinned GOV.UK One Login Simulator GHCR digest." >&2
  exit 1
fi

source_digest="${source_image##*@}"
destination_tag="source-${source_digest#sha256:}"
destination_image="${ecr_registry}/${ecr_repository}:${destination_tag}"

docker pull --platform linux/amd64 "$source_image"
docker tag "$source_image" "$destination_image"
docker push "$destination_image"

destination_digest="$(
  aws ecr describe-images \
    --repository-name "$ecr_repository" \
    --image-ids "imageTag=${destination_tag}" \
    --query 'imageDetails[0].imageDigest' \
    --output text
)"

if [[ ! "$destination_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "ECR did not return a valid destination image digest." >&2
  exit 1
fi

echo "source-image=${source_image}"
echo "destination-image=${destination_image}"
echo "destination-digest=${destination_digest}"
