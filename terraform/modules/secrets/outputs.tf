############################################
# modules/secrets/outputs.tf
############################################

output "kms_key_arn" {
  description = "KMS key ARN used for RDS, EBS, EKS secrets encryption, and Secrets Manager (feed into modules/eks, modules/eks-nodegroup)"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.main.key_id
}

output "kms_alias_name" {
  description = "KMS key alias name"
  value       = aws_kms_alias.main.name
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master username/password (feed into modules/rds -> rds_master_secret_arn)"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_master_username" {
  description = "RDS master username (feed into modules/rds -> rds_master_username)"
  value       = var.db_master_username
}

output "db_master_password" {
  description = "RDS master password (feed into modules/rds -> rds_master_password). Sensitive."
  value       = random_password.db_master.result
  sensitive   = true
}

output "schema_secret_arns" {
  description = "Map of schema name -> Secrets Manager ARN holding that schema's DB user credentials (feed into modules/rds -> schema_secret_arns)"
  value       = { for schema, secret in aws_secretsmanager_secret.schema_credentials : schema => secret.arn }
}

output "jwt_signing_key_secret_arn" {
  description = "Secrets Manager ARN holding the JWT signing key (used by auth-service's IRSA policy)"
  value       = aws_secretsmanager_secret.jwt_signing_key.arn
}

output "service_secret_arns" {
  description = "Map of service name -> Secrets Manager ARN (feed into envs/dev/main.tf -> module.iam_eks_irsa inline_policy_json Resource)"
  value       = { for svc, secret in aws_secretsmanager_secret.service_secrets : svc => secret.arn }
}
