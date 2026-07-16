resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/auto-repair-shop/${var.environment}/eks/cluster-name"
  type  = "String"
  value = module.eks.cluster_name
}

resource "aws_ssm_parameter" "order_db_secret_arn" {
  name        = "/auto-repair-shop/${var.environment}/order/db/secret-arn"
  type        = "String"
  value       = module.rds["order"].secret_arn_app
  description = "ARN do Secrets Manager com credenciais do order (JSON: host, port, dbname, username, password)"
}

resource "aws_ssm_parameter" "billing_db_secret_arn" {
  name        = "/auto-repair-shop/${var.environment}/billing/db/secret-arn"
  type        = "String"
  value       = module.rds["billing"].secret_arn_app
  description = "ARN do Secrets Manager com credenciais do billing (JSON: host, port, dbname, username, password)"
}
