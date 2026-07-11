############################################
# modules/eks/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster (e.g. novabank-dev, novabank-prod)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.29"
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS cluster (created in modules/iam-eks)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (private subnets) for the EKS control plane ENIs"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID used by worker nodes, allowed to reach the cluster API on 443"
  type        = string
}

variable "endpoint_private_access" {
  description = "Whether the EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access the public API endpoint (only used if endpoint_public_access = true)"
  type        = list(string)
  default     = []
}

variable "enabled_cluster_log_types" {
  description = "List of EKS control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for EKS control plane logs"
  type        = number
  default     = 14
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt Kubernetes secrets at rest"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
