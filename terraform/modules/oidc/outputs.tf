############################################
# modules/oidc/outputs.tf
############################################

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (feed into modules/iam-eks -> oidc_provider_arn for IRSA trust policies)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// prefix (feed into modules/iam-eks -> oidc_provider_url)"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "oidc_provider_full_url" {
  description = "Full OIDC issuer URL including https://, as returned by EKS"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "thumbprint" {
  description = "SHA1 thumbprint of the OIDC issuer's root CA certificate"
  value       = aws_iam_openid_connect_provider.eks.thumbprint_list[0]
}
