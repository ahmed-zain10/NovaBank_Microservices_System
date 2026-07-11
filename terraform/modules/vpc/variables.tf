############################################
# modules/vpc/variables.tf
############################################

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used to tag subnets for auto-discovery by EKS and the AWS Load Balancer Controller"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across (2 for dev, 3 for prod)"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway (cheaper, dev) instead of one per AZ (HA, prod)"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch log retention for VPC Flow Logs"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
