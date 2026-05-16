// DB resources for the app: stored in AWS Secrets Manager so the app pod
// can read its credentials at runtime. The actual database/role creation
// happens in module.k8s via a Kubernetes Job (see modules/k8s/db-init.tf).
// That Job runs in-cluster and reaches the private RDS endpoint without
// needing an ARC self-hosted runner.

resource "aws_secretsmanager_secret" "app" {
  name                    = "auto-repair-shop/${var.environment}/db-app"
  description             = "RDS app user credentials for ${var.environment}"
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    username = "app_${var.environment}"
    password = var.db_app_password
    host     = var.rds_endpoint
    port     = var.rds_port
    dbname   = "auto_repair_shop_${var.environment}"
  })
}
