############################################
# modules/iam-eks/iam.tf
############################################

#############################
# 1) EKS Cluster IAM Role
#    (used by modules/eks -> cluster_role_arn)
#############################

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count              = var.create_base_roles ? 1 : 0
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-eks-cluster-role" }
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create_base_roles ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Required if the control plane also manages VPC resources (ENIs) directly
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  count      = var.create_base_roles ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

#############################
# 2) EKS Worker Node IAM Role
#    (used by modules/eks-nodegroup -> node_role_arn)
#############################

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count              = var.create_base_roles ? 1 : 0
  name               = "${var.cluster_name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-eks-node-role" }
  )
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = var.create_base_roles ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.create_base_roles ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  count      = var.create_base_roles ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Lets you exec into nodes via Session Manager instead of opening SSH (better for a bank)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  count      = var.create_base_roles && var.enable_ssm_on_nodes ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "eks_node" {
  count = var.create_base_roles ? 1 : 0
  name  = "${var.cluster_name}-eks-node-profile"
  role  = aws_iam_role.eks_node[0].name
}

#############################
# 3) IRSA Roles (IAM Roles for Service Accounts)
#    One role per microservice, scoped to its own
#    K8s namespace + service account via OIDC federation.
#    Depends on modules/oidc output (provider_arn, provider_url).
#############################

data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = var.irsa_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = var.irsa_roles

  name               = "${var.cluster_name}-${each.key}-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role[each.key].json

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-${each.key}-irsa-role" }
  )
}

# Attach AWS managed policies (e.g. Secrets Manager read, SQS, S3) per service
resource "aws_iam_role_policy_attachment" "irsa_managed" {
  for_each = {
    for pair in flatten([
      for svc, cfg in var.irsa_roles : [
        for arn in cfg.policy_arns : {
          key = "${svc}-${arn}"
          svc = svc
          arn = arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.irsa[each.value.svc].name
  policy_arn = each.value.arn
}

# Optional inline policy per service (e.g. scoped Secrets Manager access)
resource "aws_iam_role_policy" "irsa_inline" {
  for_each = { for svc, cfg in var.irsa_roles : svc => cfg if cfg.inline_policy_json != null }

  name   = "${var.cluster_name}-${each.key}-inline-policy"
  role   = aws_iam_role.irsa[each.key].id
  policy = each.value.inline_policy_json
}
