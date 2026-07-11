############################################
# modules/oidc/oidc.tf
# IAM OIDC Provider for IRSA
# (bridges modules/eks -> modules/iam-eks)
############################################

# Fetch the TLS certificate chain of the cluster's OIDC issuer
# so we can pin its root CA thumbprint on the IAM OIDC provider.
data "tls_certificate" "eks_oidc" {
  url = var.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = var.cluster_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint,
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-oidc-provider"
    }
  )
}
