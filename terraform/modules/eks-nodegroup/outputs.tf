############################################
# modules/eks-nodegroup/outputs.tf
############################################

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Current status of the node group"
  value       = aws_eks_node_group.this.status
}

output "node_group_resources" {
  description = "Underlying autoscaling group(s) backing this node group"
  value       = aws_eks_node_group.this.resources
}

output "autoscaling_group_names" {
  description = "Names of the autoscaling groups created by EKS for this node group (used by cluster-autoscaler tagging)"
  value       = [for r in aws_eks_node_group.this.resources : r.autoscaling_groups[*].name]
}

output "launch_template_id" {
  description = "ID of the launch template used by this node group"
  value       = aws_launch_template.this.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the launch template"
  value       = aws_launch_template.this.latest_version
}
