############################################
# modules/oidc/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster, used for tagging the OIDC provider"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster (from modules/eks -> cluster_oidc_issuer_url output)"
  type        = string
}

variable "tags" {
  description = "Common tags applied to the OIDC provider"
  type        = map(string)
  default     = {}
}
