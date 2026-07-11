############################################
# modules/iam-eks/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster, used as a prefix for all IAM role names"
  type        = string
}

variable "enable_ssm_on_nodes" {
  description = "Attach AmazonSSMManagedInstanceCore to the node role, allowing Session Manager access instead of SSH"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for this cluster (from modules/oidc). Required only if irsa_roles is non-empty."
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// prefix (from modules/oidc), used in the trust policy condition"
  type        = string
  default     = ""
}

variable "irsa_roles" {
  description = <<-EOT
    Map of IRSA roles to create, one per microservice that needs AWS permissions
    from inside its pod (e.g. auth-service reading JWT signing key from Secrets Manager,
    notifications-service publishing to SNS/SQS).

    key = logical service name (e.g. "auth-service", "notifications-service")
  EOT
  type = map(object({
    namespace          = string       # K8s namespace the service account lives in
    service_account    = string       # K8s ServiceAccount name
    policy_arns        = list(string) # AWS managed/customer managed policy ARNs to attach
    inline_policy_json = optional(string) # optional scoped inline policy (e.g. specific secret ARN only)
  }))
  default = {}

  # Example:
  # irsa_roles = {
  #   "auth-service" = {
  #     namespace       = "auth"
  #     service_account = "auth-service-sa"
  #     policy_arns     = []
  #     inline_policy_json = jsonencode({
  #       Version = "2012-10-17"
  #       Statement = [{
  #         Effect   = "Allow"
  #         Action   = ["secretsmanager:GetSecretValue"]
  #         Resource = "arn:aws:secretsmanager:eu-west-1:ACCOUNT:secret:novabank/dev/auth-*"
  #       }]
  #     })
  #   }
  # }
}

variable "tags" {
  description = "Common tags applied to all IAM resources in this module"
  type        = map(string)
  default     = {}
}
