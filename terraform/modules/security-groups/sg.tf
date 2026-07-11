############################################
# modules/security-groups/sg.tf
############################################

# ------------------------------------------------------------------
# EKS Worker Node Security Group
# Replaces the old ECS task security group. This SG is attached to
# every node's ENI. Cross-rules with the EKS control plane SG
# (created in modules/eks) are added there, not here, to avoid a
# circular module dependency — see modules/eks/cluster.tf.
# ------------------------------------------------------------------

resource "aws_security_group" "eks_nodes" {
  name        = "${var.environment}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound (ECR pulls, AWS API calls, internet via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.environment}-eks-nodes-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Node-to-node communication — required for CNI (pod-to-pod across nodes),
# kube-proxy, and DaemonSets like the ALB controller's webhook.
resource "aws_security_group_rule" "eks_nodes_self_ingress" {
  description              = "Allow nodes to communicate with each other on all ports"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# ------------------------------------------------------------------
# RDS Security Group
# Only reachable from EKS worker nodes (pods use the node's ENI / or
# their own via VPC CNI ENI trunking — either way, traffic originates
# from an ENI carrying the node SG).
# ------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL, allows access from EKS nodes only"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { Name = "${var.environment}-rds-sg" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_from_nodes" {
  description              = "Allow Postgres access from EKS worker nodes"
  type                     = "ingress"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "rds_egress" {
  description       = "Allow all outbound from RDS (needed for extensions, patching)"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

# ------------------------------------------------------------------
# VPC Interface Endpoints Security Group
# Used by PrivateLink endpoints (ECR api/dkr, Secrets Manager,
# CloudWatch Logs, STS) so nodes in private subnets without a NAT
# route (or with restricted egress) can still reach AWS APIs.
# ------------------------------------------------------------------

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints_sg ? 1 : 0

  name        = "${var.environment}-vpc-endpoints-sg"
  description = "Security group for VPC interface endpoints (ECR, Secrets Manager, CloudWatch Logs, STS)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { Name = "${var.environment}-vpc-endpoints-sg" }
  )
}

resource "aws_security_group_rule" "vpc_endpoints_ingress_from_nodes" {
  count = var.enable_vpc_endpoints_sg ? 1 : 0

  description              = "Allow HTTPS from EKS nodes to VPC endpoints"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints[0].id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "vpc_endpoints_egress" {
  count = var.enable_vpc_endpoints_sg ? 1 : 0

  description       = "Allow all outbound from VPC endpoints ENIs"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpc_endpoints[0].id
}
