############################################
# envs/dev/variables.tf
############################################

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "image_tag" {
  description = <<-EOT
    Docker image tag passed by the Jenkins pipeline (e.g. v1.0.0, or a git SHA).
    Not consumed directly by any Terraform resource in this EKS setup (image
    tags are set in Kubernetes Deployment manifests, not in Terraform), but
    declared here so `terraform plan -var="image_tag=..."` from the pipeline
    doesn't fail. Safe to reference later if you add an ECR lifecycle policy
    or a data source keyed on it.
  EOT
  type    = string
  default = "latest"
}

# ---------------- Networking ----------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway instead of one per AZ. True in dev to save cost."
  type        = bool
  default     = true
}

# ---------------- RDS ----------------

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_master_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  default     = "novabank_admin"
}

variable "rds_multi_az" {
  description = "Whether RDS runs Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_backup_retention_days" {
  description = "RDS automated backup retention in days"
  type        = number
  default     = 3
}

variable "rds_deletion_protection" {
  description = "Whether RDS has deletion protection enabled"
  type        = bool
  default     = false
}

# ---------------- EKS ----------------

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "novabank-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "eks_endpoint_public_access" {
  description = "Whether the EKS public API endpoint is enabled (true is acceptable for dev convenience)"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint, if enabled. Defaults to 0.0.0.0/0 to match what AWS auto-fills — leaving this empty causes Terraform to detect a false diff on every apply."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention for EKS control plane logs"
  type        = number
  default     = 14
}

# ---------------- Node Group ----------------

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "SPOT"
}

variable "node_instance_types" {
  description = "EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "Root EBS volume size (GB) for each node"
  type        = number
  default     = 50
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of nodes at creation time"
  type        = number
  default     = 2
}

# ---------------- Helm / DNS ----------------

variable "enable_external_dns" {
  description = "Whether to install external-dns"
  type        = bool
  default     = false
}

# ---------------- Domains / ACM ----------------

variable "hosted_zone_name" {
  description = "Route53 hosted zone (e.g. novabank.yourdomain.com)"
  type        = string
}

variable "customer_domain" {
  description = "Customer-facing domain (e.g. app-dev.novabank.yourdomain.com)"
  type        = string
}

variable "teller_domain" {
  description = "Teller portal domain (e.g. teller-dev.novabank.yourdomain.com)"
  type        = string
}

variable "acm_certificate_arn_us_east_1" {
  description = "ACM certificate ARN in us-east-1, required by CloudFront"
  type        = string
}

variable "alb_origin_domain" {
  description = <<-EOT
    DNS name of the ALB created by the AWS Load Balancer Controller from your
    Ingress objects. Unknown at first apply (Step 9 in README) — set this
    after the Ingress is applied and CloudFront needs to be pointed at it,
    then re-apply just the cloudfront module with -target if needed.
  EOT
  type    = string
  default = ""
}

# ---------------- Teller access ----------------

variable "teller_allowed_ips" {
  description = "CIDR list of office IP(s) allowed to access the teller portal"
  type        = list(string)
}
