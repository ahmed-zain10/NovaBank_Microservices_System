############################################
# modules/addons/outputs.tf
############################################

output "vpc_cni_addon_arn" {
  description = "ARN of the installed vpc-cni add-on"
  value       = aws_eks_addon.vpc_cni.arn
}

output "coredns_addon_arn" {
  description = "ARN of the installed coredns add-on"
  value       = aws_eks_addon.coredns.arn
}

output "kube_proxy_addon_arn" {
  description = "ARN of the installed kube-proxy add-on"
  value       = aws_eks_addon.kube_proxy.arn
}

output "ebs_csi_addon_arn" {
  description = "ARN of the installed aws-ebs-csi-driver add-on (empty if disabled)"
  value       = try(aws_eks_addon.ebs_csi[0].arn, null)
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver's service account (empty if disabled)"
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}
