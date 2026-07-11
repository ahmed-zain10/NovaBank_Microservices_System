############################################
# modules/waf/waf.tf
#
# IMPORTANT — scope is CLOUDFRONT, not REGIONAL.
# In this architecture WAF always sat between CloudFront and the ALB
# (see README diagram), never attached to the ALB directly. That was
# true before EKS and remains true now — nothing changes here because
# of the ECS -> EKS migration. CLOUDFRONT-scope Web ACLs must be
# created in us-east-1 regardless of your main region, so this module
# must be called with a us-east-1 provider alias:
#
#   module "waf" {
#     source    = "../../modules/waf"
#     providers = { aws = aws.us_east_1 }
#     ...
#   }
############################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.50"
      configuration_aliases = [aws]
    }
  }
}

# ------------------------------------------------------------------
# IP set for the teller portal allowlist
# ------------------------------------------------------------------

resource "aws_wafv2_ip_set" "teller_allowed" {
  name               = "${var.environment}-teller-allowed-ips"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.teller_allowed_ips

  tags = merge(
    var.tags,
    { Name = "${var.environment}-teller-allowed-ips" }
  )
}

# ------------------------------------------------------------------
# Customer Web ACL — public traffic, rate limiting, OWASP managed rules
# ------------------------------------------------------------------

resource "aws_wafv2_web_acl" "customers" {
  name        = "${var.environment}-customers-waf"
  description = "WAF for the customer-facing portal: rate limiting + OWASP managed rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_requests_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-customers-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-customers-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-customers-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-customers-sqli"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-customers-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    { Name = "${var.environment}-customers-waf" }
  )
}

# ------------------------------------------------------------------
# Teller Web ACL — IP allowlist + OWASP managed rules
# (geo-restriction to Egypt is handled at the CloudFront distribution
# level in modules/cloudfront, not here)
# ------------------------------------------------------------------

resource "aws_wafv2_web_acl" "teller" {
  name        = "${var.environment}-teller-waf"
  description = "WAF for the teller portal: office IP allowlist + OWASP managed rules"
  scope       = "CLOUDFRONT"

  default_action {
    block {}
  }

  rule {
    name     = "AllowOfficeIPs"
    priority = 0

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.teller_allowed.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-teller-ip-allowlist"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-teller-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-teller-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-teller-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    { Name = "${var.environment}-teller-waf" }
  )
}

# NOTE: no aws_wafv2_web_acl_association resource here — CloudFront
# Web ACLs are attached by setting web_acl_id directly on the
# aws_cloudfront_distribution resource (done in modules/cloudfront),
# not via a separate association resource. That only exists for
# REGIONAL-scope Web ACLs (ALB/API Gateway/AppSync), which this
# architecture doesn't use.
