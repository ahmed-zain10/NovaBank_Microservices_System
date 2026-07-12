############################################
# modules/secrets/kms.tf
#
# The pre-existing main.tf never created a KMS key (Secrets Manager
# secrets used the default AWS-managed key). modules/eks and
# modules/eks-nodegroup require an explicit customer-managed key, so
# it's added here rather than touching main.tf.
############################################

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
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

  # Required for the EKS Managed Node Group's Auto Scaling Group to
  # launch EC2 instances with an encrypted (customer-managed KMS key)
  # EBS root volume. Without this, node creation fails with
  # "InvalidKMSKey.InvalidState".
  statement {
    sid    = "AllowAutoScalingGrantCreation"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    sid    = "AllowAutoScalingUseOfKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }

    resources = ["*"]
  }
}

resource "aws_kms_key" "main" {
  description             = "${var.project}-${var.env} encryption key (RDS, EBS, EKS secrets, Secrets Manager)"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(
    var.tags,
    { Name = "${var.project}-${var.env}-kms-key" }
  )
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.env}"
  target_key_id = aws_kms_key.main.key_id
}
