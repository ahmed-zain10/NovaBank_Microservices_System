############################################
# modules/eks/cluster.tf
# EKS Control Plane
############################################

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-logs"
    }
  )
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "Security group for EKS control plane ENIs"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-cluster-sg"
    }
  )
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow worker nodes to communicate with the cluster API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = var.node_security_group_id
}

# Reciprocal rule: lets the control plane reach kubelet / webhook ports on
# worker nodes (e.g. metrics-server, admission webhooks like the ALB
# controller's). Declared here — not in modules/security-groups — because
# this is the first place both the cluster SG and node SG IDs are available
# without creating a circular module dependency.
resource "aws_security_group_rule" "nodes_ingress_cluster" {
  description              = "Allow the control plane to reach kubelet API / webhooks on worker nodes"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = var.node_security_group_id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # Ensure log group and IAM role are ready before the cluster is created
  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}
