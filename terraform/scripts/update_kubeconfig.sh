#!/bin/bash
############################################
# scripts/update_kubeconfig.sh
#
# Usage: ./update_kubeconfig.sh <env> <region>
# Example: ./update_kubeconfig.sh dev eu-west-1
############################################

set -euo pipefail

ENV="${1:-}"
REGION="${2:-}"

if [ -z "$ENV" ] || [ -z "$REGION" ]; then
  echo "Usage: $0 <env> <region>"
  echo "Example: $0 dev eu-west-1"
  exit 1
fi

CLUSTER_NAME="novabank-${ENV}"

echo "==> Updating kubeconfig for cluster '${CLUSTER_NAME}' in ${REGION}..."

aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --alias "novabank-${ENV}"

echo "==> Verifying cluster access..."

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: could not reach the cluster. Check that:" >&2
  echo "  - your AWS credentials/SSO session are valid" >&2
  echo "  - your IAM identity is mapped in the aws-auth ConfigMap / EKS access entries" >&2
  echo "  - the cluster's public endpoint is reachable from here (if endpoint_public_access=false, you need VPN/bastion access)" >&2
  exit 1
fi

echo ""
echo "==> Nodes:"
kubectl get nodes -o wide

echo ""
echo "==> System pods:"
kubectl get pods -n kube-system

echo ""
echo "kubeconfig updated. Context: novabank-${ENV}"
