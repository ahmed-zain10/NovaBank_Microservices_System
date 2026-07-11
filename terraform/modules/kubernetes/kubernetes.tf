############################################
# modules/kubernetes/kubernetes.tf
#
# NOTE: the `kubernetes` provider must be configured at the
# ENV level (envs/dev, envs/prod) exactly like in modules/helm.
# This module only consumes it.
############################################

# ------------------------------------------------------------------
# Namespaces — one per microservice, mirrors the DB schema isolation
# from the original ECS setup (auth, accounts, transactions, notifications)
# plus gateway/frontend namespaces.
# ------------------------------------------------------------------

resource "kubernetes_namespace" "this" {
  for_each = var.namespaces

  metadata {
    name = each.key

    labels = merge(
      {
        "app.kubernetes.io/managed-by" = "terraform"
        "novabank.com/environment"     = var.environment
      },
      each.value.labels
    )
  }
}

# ------------------------------------------------------------------
# Service Accounts — annotated with the matching IRSA role ARN
# (from modules/iam-eks -> irsa_role_arns) so each pod only gets
# the AWS permissions its own microservice needs.
# ------------------------------------------------------------------

resource "kubernetes_service_account" "this" {
  for_each = var.service_accounts

  metadata {
    name      = each.value.name
    namespace = each.value.namespace

    annotations = merge(
      each.value.irsa_role_arn != null ? {
        "eks.amazonaws.com/role-arn" = each.value.irsa_role_arn
      } : {},
      each.value.extra_annotations
    )
  }

  automount_service_account_token = true

  depends_on = [kubernetes_namespace.this]
}

# ------------------------------------------------------------------
# Resource Quotas — prevents one noisy-neighbor namespace (e.g. a
# runaway transactions-service rollout) from starving the others.
# ------------------------------------------------------------------

resource "kubernetes_resource_quota" "this" {
  for_each = var.namespaces

  metadata {
    name      = "${each.key}-quota"
    namespace = each.key
  }

  spec {
    hard = {
      "requests.cpu"    = each.value.quota_cpu_requests
      "requests.memory" = each.value.quota_memory_requests
      "limits.cpu"      = each.value.quota_cpu_limits
      "limits.memory"   = each.value.quota_memory_limits
      "pods"            = each.value.quota_max_pods
    }
  }

  depends_on = [kubernetes_namespace.this]
}

# ------------------------------------------------------------------
# Default-deny NetworkPolicy per namespace — zero-trust baseline.
# Each service must get an explicit allow policy on top of this
# (e.g. api-gateway -> auth-service only), which keeps the lateral
# movement blast radius small for a banking workload.
# ------------------------------------------------------------------

resource "kubernetes_network_policy" "default_deny" {
  for_each = var.enable_default_deny_network_policy ? var.namespaces : {}

  metadata {
    name      = "default-deny-all"
    namespace = each.key
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }

  depends_on = [kubernetes_namespace.this]
}

# Always allow DNS egress (to kube-dns/coredns) even under default-deny,
# otherwise nothing in the namespace can resolve service names.
resource "kubernetes_network_policy" "allow_dns_egress" {
  for_each = var.enable_default_deny_network_policy ? var.namespaces : {}

  metadata {
    name      = "allow-dns-egress"
    namespace = each.key
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }

  depends_on = [kubernetes_namespace.this]
}
