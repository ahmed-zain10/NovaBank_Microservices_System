############################################
# modules/eks/outputs.tf
############################################

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint URL for the Kubernetes API server (used by kubectl/helm/kubernetes providers)"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data, required to connect to the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane"
  value       = aws_eks_cluster.this.version
}

# Needed by modules/oidc to create the IAM OIDC provider (IRSA)
output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster, used to set up IRSA in modules/oidc"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane ENIs"
  value       = aws_security_group.eks_cluster.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group storing EKS control plane logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}
