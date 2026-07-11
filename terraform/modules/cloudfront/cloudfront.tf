############################################
# modules/cloudfront/cloudfront.tf
#
# NOTE: var.alb_origin_domain is the DNS name of the ALB created
# dynamically by the AWS Load Balancer Controller (from Kubernetes
# Ingress objects) — not a Terraform-managed ALB anymore. It is
# unknown at first apply; see README "CloudFront <-> ALB" note.
############################################

# ------------------------------------------------------------------
# Secret header — CloudFront injects this on every request to the
# ALB; the Ingress/ALB listener rule only forwards traffic that
# carries the correct value, blocking anyone who hits the ALB's
# public DNS name directly.
# ------------------------------------------------------------------

resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

# ------------------------------------------------------------------
# Customer-facing distribution
# ------------------------------------------------------------------

resource "aws_cloudfront_distribution" "customers" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = var.price_class
  aliases             = [var.customer_domain]
  web_acl_id          = var.waf_customer_acl_arn
  comment             = "${var.environment} NovaBank customer portal"

  origin {
    domain_name = var.alb_origin_domain
    origin_id   = "customers-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_verify.result
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "customers-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress                = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Host", "Origin"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn_us_east_1
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(
    var.tags,
    { Name = "${var.environment}-customers-cf" }
  )
}

# ------------------------------------------------------------------
# Teller-facing distribution — internal staff portal, restricted to
# Egypt via geo-restriction, on top of the WAF IP allowlist.
# ------------------------------------------------------------------

resource "aws_cloudfront_distribution" "teller" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = var.price_class
  aliases             = [var.teller_domain]
  web_acl_id          = var.waf_teller_acl_arn
  comment             = "${var.environment} NovaBank teller portal"

  origin {
    domain_name = var.alb_origin_domain
    origin_id   = "teller-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_verify.result
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "teller-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress                = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Host", "Origin"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = var.teller_geo_restriction_countries
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn_us_east_1
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(
    var.tags,
    { Name = "${var.environment}-teller-cf" }
  )
}

# ------------------------------------------------------------------
# Route53 records
# ------------------------------------------------------------------

data "aws_route53_zone" "this" {
  name = var.hosted_zone_name
}

resource "aws_route53_record" "customers" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.customer_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.customers.domain_name
    zone_id                = aws_cloudfront_distribution.customers.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "teller" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.teller_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.teller.domain_name
    zone_id                = aws_cloudfront_distribution.teller.hosted_zone_id
    evaluate_target_health = false
  }
}
