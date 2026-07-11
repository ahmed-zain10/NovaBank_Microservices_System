############################################
# modules/secrets/secrets.tf
############################################

# ------------------------------------------------------------------
# KMS Key — single key used to encrypt everything at rest:
# RDS, EBS node volumes, Kubernetes secrets (EKS envelope encryption),
# ECR, and the Secrets Manager secrets created below.
# ------------------------------------------------------------------

resource "aws_kms_key" "main" {
  description             = "${var.environment} NovaBank encryption key (RDS, EBS, EKS secrets, Secrets Manager, ECR)"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(
    var.tags,
    { Name = "${var.environment}-novabank-kms-key" }
  )
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.environment}-novabank"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  # Root account always retains full control (required so you never lock
  # yourself out of the key via IAM policy changes elsewhere)
  statement {
    sid     = "EnableRootAccountAccess"
    effect  = "Allow"
    actions = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    resources = ["*"]
  }

  # Allows EKS to use this key for Kubernetes secrets envelope encryption
  statement {
    sid    = "AllowEKSUseOfKey"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    resources = ["*"]
  }

  # Allows RDS to use this key
  statement {
    sid    = "AllowRDSUseOfKey"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
    ]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }

    resources = ["*"]
  }
}

# ------------------------------------------------------------------
# Database master credentials
# Consumed by modules/rds to set the master user password.
# ------------------------------------------------------------------

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "novabank/${var.environment}/db-credentials"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(
    var.tags,
    { Name = "${var.environment}-db-credentials" }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master.result
  })
}

# ------------------------------------------------------------------
# JWT signing secret
# Used by auth-service to sign/verify tokens across all services.
# ------------------------------------------------------------------

resource "random_password" "jwt_signing_key" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name                    = "novabank/${var.environment}/jwt-signing-key"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(
    var.tags,
    { Name = "${var.environment}-jwt-signing-key" }
  )
}

resource "aws_secretsmanager_secret_version" "jwt_signing_key" {
  secret_id     = aws_secretsmanager_secret.jwt_signing_key.id
  secret_string = random_password.jwt_signing_key.result
}

# ------------------------------------------------------------------
# Per-service secrets
# One Secrets Manager secret per microservice (key = service name,
# matching local.microservices in envs/dev/main.tf). Each service's
# IRSA role is scoped to read only its own secret ARN — see
# modules/iam-eks irsa_roles.inline_policy_json.
# ------------------------------------------------------------------

resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = var.services

  name                    = "novabank/${var.environment}/${each.key}"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(
    var.tags,
    { Name = "${var.environment}-${each.key}-secret" }
  )
}

resource "aws_secretsmanager_secret_version" "service_secrets" {
  for_each = var.services

  secret_id     = aws_secretsmanager_secret.service_secrets[each.key].id
  secret_string = jsonencode(each.value)

  lifecycle {
    # Values are typically filled in / rotated out-of-band after creation
    # (e.g. via a rotation Lambda or manually); don't fight manual updates.
    ignore_changes = [secret_string]
  }
}
