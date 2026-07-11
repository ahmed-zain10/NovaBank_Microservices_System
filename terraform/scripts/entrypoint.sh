#!/bin/sh
############################################
# scripts/entrypoint.sh
#
# CHANGED FOR EKS: the old ECS version pulled credentials from the
# ECS task metadata endpoint (169.254.170.2) using the task role.
# On EKS, the pod's ServiceAccount is annotated with an IRSA role
# (eks.amazonaws.com/role-arn), and EKS's Pod Identity webhook
# automatically injects AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE
# into the container — the AWS CLI/SDK picks these up with zero
# extra config. No metadata endpoint calls needed at all.
#
# Required env vars (set these in the K8s Deployment manifest):
#   SECRET_NAME   e.g. novabank/dev/auth-service
#   AWS_REGION    e.g. eu-west-1
#
# Optional:
#   SECRET_ENV_PREFIX   prefix added to each exported var name (default: none)
############################################

set -eu

if [ -z "${SECRET_NAME:-}" ]; then
  echo "entrypoint.sh: SECRET_NAME is not set, skipping secret injection" >&2
else
  echo "entrypoint.sh: fetching secret '${SECRET_NAME}' via IRSA..." >&2

  SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" \
    --region "${AWS_REGION:-eu-west-1}" \
    --query 'SecretString' \
    --output text)

  if [ -z "${SECRET_JSON}" ]; then
    echo "entrypoint.sh: ERROR - empty secret value for '${SECRET_NAME}'" >&2
    exit 1
  fi

  # Export each key in the secret JSON as an environment variable.
  # Requires `jq` in the container image.
  eval "$(
    echo "${SECRET_JSON}" | jq -r '
      to_entries[] |
      "export " + (env.SECRET_ENV_PREFIX // "") + .key + "=" + (.value | @sh)
    '
  )"

  echo "entrypoint.sh: secret injected as environment variables" >&2
fi

# Hand off to the actual container command (e.g. uvicorn main:app ...)
exec "$@"
