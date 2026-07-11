############################################
# modules/kubernetes/outputs.tf
############################################

output "namespace_names" {
  description = "List of namespace names created"
  value       = [for ns in kubernetes_namespace.this : ns.metadata[0].name]
}

output "service_account_names" {
  description = "Map of service key -> { namespace, name } for each created ServiceAccount"
  value = {
    for k, sa in kubernetes_service_account.this : k => {
      namespace = sa.metadata[0].namespace
      name      = sa.metadata[0].name
    }
  }
}

output "default_deny_enabled_namespaces" {
  description = "List of namespaces that have the default-deny NetworkPolicy applied"
  value       = [for np in kubernetes_network_policy.default_deny : np.metadata[0].namespace]
}
