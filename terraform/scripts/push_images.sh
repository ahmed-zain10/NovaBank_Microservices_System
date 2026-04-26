#!/bin/bash
###############################################################################
# NovaBank – Build & Push Docker Images to ECR
# Usage: ./scripts/push_images.sh <env> <region> <account_id> [image_tag]
#
# Example:
#   ./scripts/push_images.sh dev eu-west-1 123456789012 v1.0.0
###############################################################################

set -euo pipefail

ENV="${1:?Usage: $0 <env> <region> <account_id> [image_tag]}"
REGION="${2:?Missing region}"
ACCOUNT_ID="${3:?Missing account_id}"
IMAGE_TAG="${4:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

PROJECT="novabank"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 NovaBank Docker Build & Push"
echo "   ENV:        ${ENV}"
echo "   REGION:     ${REGION}"
echo "   ACCOUNT:    ${ACCOUNT_ID}"
echo "   TAG:        ${IMAGE_TAG}"
echo "   REGISTRY:   ${REGISTRY}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Authenticate to ECR ────────────────────────────────────────────────────────
echo ""
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin "${REGISTRY}"
echo "   ✅ ECR login successful"

# ── Service definitions ────────────────────────────────────────────────────────
# Format: "service_name:context_path:dockerfile_path"
declare -a SERVICES=(
  "auth-service:${ROOT_DIR}/services/auth-service:${ROOT_DIR}/services/auth-service/Dockerfile"
  "accounts-service:${ROOT_DIR}/services/accounts-service:${ROOT_DIR}/services/accounts-service/Dockerfile"
  "transactions-service:${ROOT_DIR}/services/transactions-service:${ROOT_DIR}/services/transactions-service/Dockerfile"
  "notifications-service:${ROOT_DIR}/services/notifications-service:${ROOT_DIR}/services/notifications-service/Dockerfile"
  "api-gateway:${ROOT_DIR}/services/api-gateway:${ROOT_DIR}/services/api-gateway/Dockerfile"
  "frontend-customers:${ROOT_DIR}/services/frontend-customers:${ROOT_DIR}/services/frontend-customers/Dockerfile"
  "frontend-teller:${ROOT_DIR}/services/frontend-teller:${ROOT_DIR}/services/frontend-teller/Dockerfile"
)

FAILED=()

for svc_def in "${SERVICES[@]}"; do
  IFS=':' read -r SVC_NAME CONTEXT DOCKERFILE <<< "${svc_def}"
  REPO="${PROJECT}/${ENV}/${SVC_NAME}"
  FULL_IMAGE="${REGISTRY}/${REPO}:${IMAGE_TAG}"
  LATEST_IMAGE="${REGISTRY}/${REPO}:latest"

  echo ""
  echo "▶ Building ${SVC_NAME}..."
  echo "  Context:    ${CONTEXT}"
  echo "  Dockerfile: ${DOCKERFILE}"
  echo "  Image:      ${FULL_IMAGE}"

  if [ ! -f "${DOCKERFILE}" ]; then
    echo "  ⚠️  Dockerfile not found at ${DOCKERFILE}, skipping."
    FAILED+=("${SVC_NAME}")
    continue
  fi

  # Build
  if docker build \
    --platform linux/amd64 \
    --file "${DOCKERFILE}" \
    --tag "${FULL_IMAGE}" \
    --tag "${LATEST_IMAGE}" \
    --build-arg ENV="${ENV}" \
    --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg GIT_SHA="${IMAGE_TAG}" \
    "${CONTEXT}"; then

    # Push versioned tag
    echo "  📤 Pushing ${IMAGE_TAG}..."
    docker push "${FULL_IMAGE}"

    # Also push 'latest' tag (useful for dev)
    if [ "${ENV}" = "dev" ]; then
      echo "  📤 Pushing latest..."
      docker push "${LATEST_IMAGE}"
    fi

    echo "  ✅ ${SVC_NAME} pushed successfully"
  else
    echo "  ❌ Build failed for ${SVC_NAME}"
    FAILED+=("${SVC_NAME}")
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "✅ All images built and pushed successfully!"
  echo ""
  echo "🚀 To deploy with the new tag, run:"
  echo "   cd envs/${ENV}"
  echo "   terraform apply -var='image_tag=${IMAGE_TAG}' -var-file=terraform.tfvars"
else
  echo "❌ Failed services: ${FAILED[*]}"
  exit 1
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
