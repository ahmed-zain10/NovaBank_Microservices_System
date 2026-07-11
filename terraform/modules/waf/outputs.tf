############################################
# modules/waf/outputs.tf
############################################

output "customer_web_acl_arn" {
  description = "ARN of the customer Web ACL (feed into modules/cloudfront -> waf_customer_acl_arn)"
  value       = aws_wafv2_web_acl.customers.arn
}

output "teller_web_acl_arn" {
  description = "ARN of the teller Web ACL (feed into modules/cloudfront -> waf_teller_acl_arn)"
  value       = aws_wafv2_web_acl.teller.arn
}

output "teller_allowed_ip_set_arn" {
  description = "ARN of the IP set used by the teller Web ACL's AllowOfficeIPs rule"
  value       = aws_wafv2_ip_set.teller_allowed.arn
}
