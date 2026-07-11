############################################
# modules/waf/variables.tf
############################################

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "teller_allowed_ips" {
  description = "CIDR list of office IP(s) allowed to access the teller portal"
  type        = list(string)
}

variable "rate_limit_requests_per_5min" {
  description = "Max requests per 5-minute window per IP before blocking, on the customer WAF"
  type        = number
  default     = 2000
}

variable "tags" {
  description = "Common tags applied to WAF resources"
  type        = map(string)
  default     = {}
}
