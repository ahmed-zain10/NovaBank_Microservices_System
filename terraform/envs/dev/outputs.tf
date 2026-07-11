############################################
# envs/dev/outputs.tf
############################################

data "aws_caller_identity" "current" {}

output "customer_portal_url" {
  description = "Customer portal URL"
  value       = "https://${var.customer_domain}"
}

output "teller_portal_url" {
  description = "Teller portal URL (IP-restricted)"
  value       = "https://${var.teller_domain}"
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS endpoint (internal, not publicly accessible)"
  value       = module.rds.rds_endpoint
  sensitive   = true
}

output "ecr_repositories" {
  description = "ECR repository URLs for pushing Docker images"
  value       = module.ecr.repository_urls
}

output "cloudwatch_log_groups" {
  description = "Log group prefix for all services"
  value       = "/novabank/${local.environment}/<service-name>"
}

output "next_steps" {
  value = <<-EOT
    ✅ Infrastructure deployed!

    Next steps:
    1. Point kubectl at the cluster:
       ./scripts/update_kubeconfig.sh dev ${var.aws_region}

    2. Build & push Docker images:
       cd ../../ && ./scripts/push_images.sh dev ${var.aws_region} ${data.aws_caller_identity.current.account_id}

    3. Apply your application Kubernetes manifests (Deployments/Services/Ingress):
       kubectl apply -f k8s/ -n <namespace>

    4. Run DB schema init (Lambda):
       aws lambda invoke --function-name novabank-dev-db-init /tmp/out.json

    5. Access your app:
       Customer Portal: https://${var.customer_domain}
       Teller Portal:   https://${var.teller_domain}

    6. View logs:
       kubectl logs -n api-gateway deploy/api-gateway --follow
  EOT
}
