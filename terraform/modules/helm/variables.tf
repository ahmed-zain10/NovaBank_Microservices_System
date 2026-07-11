############################################
# modules/helm/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster runs in (e.g. eu-west-1)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID of the cluster, required by the AWS Load Balancer Controller"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (from modules/oidc), used to build IRSA trust policies"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without https:// prefix (from modules/oidc)"
  type        = string
}

variable "alb_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller. Leave null for the latest available"
  type        = string
  default     = null
}

variable "enable_cluster_autoscaler" {
  description = "Whether to install cluster-autoscaler via Helm"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_chart_version" {
  description = "Helm chart version for cluster-autoscaler. Leave null for the latest available"
  type        = string
  default     = null
}

variable "enable_external_dns" {
  description = "Whether to install external-dns via Helm (auto-creates Route53 records from Ingress hosts)"
  type        = bool
  default     = false
}

variable "external_dns_chart_version" {
  description = "Helm chart version for external-dns. Leave null for the latest available"
  type        = string
  default     = null
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone domain filter for external-dns (e.g. novabank.yourdomain.com). Required if enable_external_dns = true"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to IAM resources created in this module"
  type        = map(string)
  default     = {}
}
