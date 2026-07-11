############################################
# modules/secrets/variables.tf
############################################

variable "project" {
  description = "Project name, used as a prefix for secret names (matches modules/rds, modules/ecr convention)"
  type        = string
}

variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "rds_master_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
}

variable "kms_deletion_window_days" {
  description = "Waiting period before the KMS key is deleted after destroy (7-30 days)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
