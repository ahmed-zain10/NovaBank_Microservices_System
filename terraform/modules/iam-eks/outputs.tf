############################################
# modules/iam-eks/outputs.tf
############################################

output "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane (feed into modules/eks -> cluster_role_arn). Null if create_base_roles = false."
  value       = try(aws_iam_role.eks_cluster[0].arn, null)
}

output "cluster_role_name" {
  description = "IAM role name for the EKS control plane. Null if create_base_roles = false."
  value       = try(aws_iam_role.eks_cluster[0].name, null)
}

output "node_role_arn" {
  description = "IAM role ARN for worker nodes (feed into modules/eks-nodegroup -> node_role_arn). Null if create_base_roles = false."
  value       = try(aws_iam_role.eks_node[0].arn, null)
}

output "node_role_name" {
  description = "IAM role name for worker nodes. Null if create_base_roles = false."
  value       = try(aws_iam_role.eks_node[0].name, null)
}

output "node_instance_profile_name" {
  description = "Instance profile name attached to worker node EC2 instances. Null if create_base_roles = false."
  value       = try(aws_iam_instance_profile.eks_node[0].name, null)
}

output "node_instance_profile_arn" {
  description = "Instance profile ARN attached to worker node EC2 instances. Null if create_base_roles = false."
  value       = try(aws_iam_instance_profile.eks_node[0].arn, null)
}

output "irsa_role_arns" {
  description = "Map of service name -> IRSA role ARN, to annotate Kubernetes ServiceAccounts (eks.amazonaws.com/role-arn)"
  value       = { for svc, role in aws_iam_role.irsa : svc => role.arn }
}

output "irsa_role_names" {
  description = "Map of service name -> IRSA role name"
  value       = { for svc, role in aws_iam_role.irsa : svc => role.name }
}
