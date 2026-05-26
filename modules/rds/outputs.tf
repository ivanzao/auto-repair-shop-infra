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
