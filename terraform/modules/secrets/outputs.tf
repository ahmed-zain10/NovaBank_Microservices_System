############################################
# modules/secrets/outputs.tf
############################################

output "kms_key_arn" {
  description = "KMS key ARN (feed into modules/eks, modules/eks-nodegroup, modules/rds -> kms_key_arn)"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.main.key_id
}

output "rds_master_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master username/password (feed into modules/rds -> rds_master_secret_arn)"
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "rds_master_username" {
  description = "RDS master username (feed into modules/rds -> rds_master_username)"
  value       = var.rds_master_username
}

output "rds_master_password" {
  description = "RDS master password (feed into modules/rds -> rds_master_password). Sensitive."
  value       = random_password.rds_master.result
  sensitive   = true
}

output "schema_secret_arns" {
  description = "Map of schema name (auth/accounts/transactions/notifications) -> Secrets Manager ARN (feed into modules/rds -> schema_secret_arns, and into IRSA inline policies)"
  value       = { for schema, secret in aws_secretsmanager_secret.schema_creds : schema => secret.arn }
}

output "jwt_secret_arn" {
  description = "Secrets Manager ARN holding the JWT signing secret"
  value       = aws_secretsmanager_secret.jwt.arn
}
