############################################
# modules/addons/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster to install add-ons into"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (from modules/oidc), required if enable_ebs_csi_driver = true"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without https:// prefix (from modules/oidc), required if enable_ebs_csi_driver = true"
  type        = string
  default     = ""
}

variable "node_group_dependency" {
  description = <<-EOT
    Pass the eks-nodegroup module's node_group_id (or any node group output) here
    so that coredns and the EBS CSI driver wait for at least one node to be Ready
    before Terraform tries to install them.
  EOT
  type    = any
  default = null
}

variable "vpc_cni_version" {
  description = "Version of the vpc-cni add-on. Leave null to let EKS choose the default compatible version"
  type        = string
  default     = null
}

variable "coredns_version" {
  description = "Version of the coredns add-on. Leave null to let EKS choose the default compatible version"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy add-on. Leave null to let EKS choose the default compatible version"
  type        = string
  default     = null
}

variable "enable_ebs_csi_driver" {
  description = "Whether to install the aws-ebs-csi-driver add-on (needed for PersistentVolumeClaims backed by EBS)"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_version" {
  description = "Version of the aws-ebs-csi-driver add-on. Leave null to let EKS choose the default compatible version"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all add-on resources"
  type        = map(string)
  default     = {}
}
