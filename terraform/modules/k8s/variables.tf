############################################
# modules/kubernetes/variables.tf
############################################

variable "environment" {
  description = "Environment name, applied as a label on every namespace (e.g. dev, prod)"
  type        = string
}

variable "namespaces" {
  description = <<-EOT
    Map of namespaces to create. key = namespace name.
    Defaults mirror the 7 services from the original ECS setup.
  EOT
  type = map(object({
    labels                = optional(map(string), {})
    quota_cpu_requests    = optional(string, "2")
    quota_memory_requests = optional(string, "4Gi")
    quota_cpu_limits      = optional(string, "4")
    quota_memory_limits   = optional(string, "8Gi")
    quota_max_pods        = optional(string, "20")
  }))

  default = {
    "api-gateway"    = {}
    "auth"           = {}
    "accounts"       = {}
    "transactions"   = {}
    "notifications"  = {}
    "frontend-customers" = {}
    "frontend-teller"    = {}
  }
}

variable "service_accounts" {
  description = <<-EOT
    Map of Kubernetes ServiceAccounts to create, one per microservice.
    key = logical service name, matching modules.iam_eks_irsa.irsa_role_arns keys
    so you can wire irsa_role_arn = module.iam_eks_irsa.irsa_role_arns[key].
  EOT
  type = map(object({
    name              = string
    namespace         = string
    irsa_role_arn     = optional(string)
    extra_annotations = optional(map(string), {})
  }))
  default = {}

  # Example:
  # service_accounts = {
  #   "auth-service" = {
  #     name          = "auth-service-sa"
  #     namespace     = "auth"
  #     irsa_role_arn = module.iam_eks_irsa.irsa_role_arns["auth-service"]
  #   }
  # }
}

variable "enable_default_deny_network_policy" {
  description = "Apply a default-deny NetworkPolicy (ingress+egress) to every namespace, with DNS egress explicitly allowed. Recommended for banking workloads."
  type        = bool
  default     = true
}
