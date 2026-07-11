############################################
# modules/cloudfront/outputs.tf
############################################

output "customers_distribution_id" {
  description = "CloudFront distribution ID for the customer portal"
  value       = aws_cloudfront_distribution.customers.id
}

output "customers_distribution_domain_name" {
  description = "CloudFront default domain name for the customer portal"
  value       = aws_cloudfront_distribution.customers.domain_name
}

output "teller_distribution_id" {
  description = "CloudFront distribution ID for the teller portal"
  value       = aws_cloudfront_distribution.teller.id
}

output "teller_distribution_domain_name" {
  description = "CloudFront default domain name for the teller portal"
  value       = aws_cloudfront_distribution.teller.domain_name
}

output "origin_verify_secret_value" {
  description = <<-EOT
    Secret value CloudFront sends as the X-Origin-Verify header on every
    request to the ALB. Configure this exact value as a listener rule
    condition on the ALB (via an Ingress annotation or a
    aws_lb_listener_rule if managed outside K8s) so the ALB rejects any
    request that doesn't carry it — this is what blocks direct ALB access.
  EOT
  value     = random_password.origin_verify.result
  sensitive = true
}
