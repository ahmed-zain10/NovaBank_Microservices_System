############################################
# modules/security-groups/outputs.tf
############################################

output "eks_node_security_group_id" {
  description = "Security group ID for EKS worker nodes (feed into modules/eks -> node_security_group_id, modules/eks-nodegroup -> node_security_group_id)"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS (feed into modules/rds -> security_group_id)"
  value       = aws_security_group.rds.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC interface endpoints (null if disabled)"
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
}
