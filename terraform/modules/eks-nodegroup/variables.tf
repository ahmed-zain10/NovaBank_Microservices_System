############################################
# modules/eks-nodegroup/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster this node group joins"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API server endpoint (from modules/eks output)"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster CA data (from modules/eks output)"
  type        = string
}

variable "nodegroup_name" {
  description = "Name of this node group (e.g. general, spot-workers, transactions-pool)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version, used to pick the correct EKS-optimized AMI via SSM"
  type        = string
  default     = "1.29"
}

variable "ami_id" {
  description = "Override AMI ID. Leave empty to auto-select the latest EKS-optimized AL2 AMI via SSM"
  type        = string
  default     = ""
}

variable "node_role_arn" {
  description = "IAM role ARN for worker nodes (created in modules/iam-eks)"
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID attached to worker node ENIs"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where worker nodes will be launched"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN to encrypt node EBS root volumes"
  type        = string
}

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH access to nodes (leave empty to disable SSH)"
  type        = string
  default     = ""
}

variable "capacity_type" {
  description = "Capacity type for the node group: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "instance_types" {
  description = "List of EC2 instance types for the node group (first type used by the launch template)"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "disk_size" {
  description = "Root EBS volume size in GB for each node"
  type        = number
  default     = 50
}

variable "min_size" {
  description = "Minimum number of nodes in the autoscaling group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes in the autoscaling group"
  type        = number
  default     = 3
}

variable "desired_size" {
  description = "Desired number of nodes at creation time (cluster-autoscaler manages it afterwards)"
  type        = number
  default     = 2
}

variable "max_unavailable" {
  description = "Max number of nodes that can be unavailable during a node group update"
  type        = number
  default     = 1
}

variable "bootstrap_extra_args" {
  description = "Extra arguments passed to the EKS bootstrap.sh script (e.g. --container-runtime containerd)"
  type        = string
  default     = ""
}

variable "node_labels" {
  description = "Kubernetes labels applied to nodes in this group (e.g. {\"workload\" = \"transactions\"})"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Kubernetes taints applied to nodes in this group"
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string # NO_SCHEDULE | NO_EXECUTE | PREFER_NO_SCHEDULE
  }))
  default = []
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
