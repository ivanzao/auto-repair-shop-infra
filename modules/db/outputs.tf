output "db_name" {
  description = "PostgreSQL database name for the app (created by module.k8s db-init Job)"
  value       = "auto_repair_shop_${var.environment}"
}

output "db_role_name" {
  description = "PostgreSQL application role name (created by module.k8s db-init Job)"
  value       = "app_${var.environment}"
}

output "secret_arn_app" {
  description = "ARN of the app credentials secret"
  value       = aws_secretsmanager_secret.app.arn
}
