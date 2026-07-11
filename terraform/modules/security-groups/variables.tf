############################################
# modules/security-groups/variables.tf
############################################

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in SG names/tags"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used to tag the node security group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (kept for reference / future rules)"
  type        = string
}

variable "rds_port" {
  description = "PostgreSQL port RDS listens on"
  type        = number
  default     = 5432
}

variable "enable_vpc_endpoints_sg" {
  description = "Whether to create a security group for VPC interface endpoints (ECR, Secrets Manager, CloudWatch Logs, STS)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all security groups in this module"
  type        = map(string)
  default     = {}
}
