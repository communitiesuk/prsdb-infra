#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" -gt 1 ]; then
  echo "Usage: bash scripts/apply-nft-with-lock.sh [--task-definitions]" >&2
  exit 1
fi
case "${1:-}" in
  "") terraform_root="$root/terraform/nft" ;;
  --task-definitions) terraform_root="$root/terraform/nft/ecs_task_definition" ;;
  *) echo "Usage: bash scripts/apply-nft-with-lock.sh [--task-definitions]" >&2; exit 1 ;;
esac
owner="local-$(uuidgen)"
account="$(aws sts get-caller-identity --query Account --output text)"
if [ "$account" != "448120078528" ]; then
  echo "Refusing to apply: credentials are not for the NFT account." >&2
  exit 1
fi

item="$(jq -cn --arg owner "$owner" '{LockID:{S:"nft-performance-operation"},Owner:{S:$owner}}')"
aws dynamodb put-item --region eu-west-2 --table-name tfstate-lock-nft --item "$item" \
  --condition-expression 'attribute_not_exists(LockID)'
echo "Acquired NFT infrastructure lock as $owner. A failed or interrupted apply retains the lock."

terraform -chdir="$terraform_root" apply

values="$(jq -cn --arg owner "$owner" '{":owner":{S:$owner}}')"
aws dynamodb delete-item --region eu-west-2 --table-name tfstate-lock-nft \
  --key '{"LockID":{"S":"nft-performance-operation"}}' \
  --condition-expression '#owner = :owner' \
  --expression-attribute-names '{"#owner":"Owner"}' \
  --expression-attribute-values "$values"
