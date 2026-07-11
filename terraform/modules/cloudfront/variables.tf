############################################
# modules/cloudfront/variables.tf
############################################

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "customer_domain" {
  description = "Customer-facing domain (e.g. app-dev.novabank.yourdomain.com)"
  type        = string
}

variable "teller_domain" {
  description = "Teller portal domain (e.g. teller-dev.novabank.yourdomain.com)"
  type        = string
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name these domains belong to"
  type        = string
}

variable "acm_certificate_arn_us_east_1" {
  description = "ACM certificate ARN in us-east-1, required by CloudFront regardless of your main region"
  type        = string
}

variable "alb_origin_domain" {
  description = <<-EOT
    DNS name of the ALB provisioned dynamically by the AWS Load Balancer
    Controller from Kubernetes Ingress objects (modules/helm). This is NOT
    a Terraform-managed resource anymore — it only exists after you've
    applied an Ingress to the cluster. See README for the two-step process
    (apply infra -> apply Ingress -> feed its ALB DNS name back here).
  EOT
  type = string
}

variable "waf_customer_acl_arn" {
  description = "WAFv2 Web ACL ARN for the customer distribution (from modules/waf)"
  type        = string
}

variable "waf_teller_acl_arn" {
  description = "WAFv2 Web ACL ARN for the teller distribution (from modules/waf)"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 for dev, PriceClass_All for prod)"
  type        = string
  default     = "PriceClass_100"
}

variable "teller_geo_restriction_countries" {
  description = "ISO country codes allowed to access the teller portal via CloudFront geo-restriction"
  type        = list(string)
  default     = ["EG"]
}

variable "tags" {
  description = "Common tags applied to CloudFront distributions"
  type        = map(string)
  default     = {}
}
