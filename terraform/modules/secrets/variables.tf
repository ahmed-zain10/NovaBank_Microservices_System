############################################
# modules/secrets/variables.tf
############################################

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "kms_deletion_window_days" {
  description = "Waiting period before the KMS key is deleted after destroy (7-30 days)"
  type        = number
  default     = 7
}

variable "secret_recovery_window_days" {
  description = "Recovery window before a deleted Secrets Manager secret is purged (0 to disable, useful in dev)"
  type        = number
  default     = 7
}

variable "db_master_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  default     = "novabank_admin"
}

variable "services" {
  description = <<-EOT
    Map of per-service secrets to create. key = service name (must match
    local.microservices in envs/dev/main.tf so IRSA roles can reference
    the matching ARN). value = initial placeholder key/value map; real
    values are typically filled in out-of-band after creation.
  EOT
  type    = map(map(string))
  default = {
    "auth-service"          = { placeholder = "set-me" }
    "accounts-service"      = { placeholder = "set-me" }
    "transactions-service"  = { placeholder = "set-me" }
    "notifications-service" = { placeholder = "set-me" }
  }
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
