output "rds_endpoint" {
  description = "RDS instance hostname"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "secret_arn_master" {
  description = "ARN of the master credentials secret"
  value       = aws_secretsmanager_secret.master.arn
}

output "secret_arn_app" {
  description = "ARN of the app credentials secret"
  value       = aws_secretsmanager_secret.app.arn
}

output "db_name" {
  description = "PostgreSQL database name for the app (created by module.k8s db-init Job)"
  value       = local.app_db_name
}

output "db_role_name" {
  description = "PostgreSQL application role name (created by module.k8s db-init Job)"
  value       = local.app_db_username
}
