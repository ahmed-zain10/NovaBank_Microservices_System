############################################
# modules/addons/addons.tf
# EKS Managed Add-ons
############################################

# ------------------------------------------------------------------
# IRSA role dedicated to the EBS CSI driver (needed to provision
# EBS volumes for PersistentVolumeClaims, e.g. stateful workloads)
# ------------------------------------------------------------------

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  count = var.enable_ebs_csi_driver ? 1 : 0

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
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role[0].json

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-ebs-csi-driver-role" }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_ebs_csi_driver ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ------------------------------------------------------------------
# vpc-cni: pod networking (ENIs + secondary IPs for pods)
# ------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = var.cluster_name
  addon_name    = "vpc-cni"
  addon_version = var.vpc_cni_version # null = let AWS pick the default compatible version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

# ------------------------------------------------------------------
# coredns: in-cluster DNS resolution
# NOTE: requires at least one node to be Ready before it can schedule,
# so it must depend on the node group being created.
# ------------------------------------------------------------------

resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = var.coredns_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [var.node_group_dependency]
}

# ------------------------------------------------------------------
# kube-proxy: cluster networking rules (iptables/IPVS) on each node
# ------------------------------------------------------------------

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = var.cluster_name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

# ------------------------------------------------------------------
# aws-ebs-csi-driver: dynamic EBS volume provisioning for PVCs
# ------------------------------------------------------------------

resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  service_account_role_arn = aws_iam_role.ebs_csi[0].arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [var.node_group_dependency]
}
