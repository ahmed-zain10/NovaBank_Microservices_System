############################################
# modules/helm/outputs.tf
############################################

output "alb_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller's service account"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_release_status" {
  description = "Status of the aws-load-balancer-controller Helm release"
  value       = helm_release.aws_load_balancer_controller.status
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by cluster-autoscaler's service account (null if disabled)"
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}

output "external_dns_role_arn" {
  description = "IAM role ARN used by external-dns's service account (null if disabled)"
  value       = try(aws_iam_role.external_dns[0].arn, null)
}
