resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/auto-repair-shop/${var.environment}/eks/cluster-name"
  type  = "String"
  value = module.eks.cluster_name
}

resource "aws_ssm_parameter" "db_secret_arn" {
  for_each = module.rds

  name        = "/auto-repair-shop/${var.environment}/${each.key}/db/secret-arn"
  type        = "String"
  value       = each.value.secret_arn_app
  description = "ARN do Secrets Manager com credenciais do ${each.key} (JSON: host, port, dbname, username, password)"
}
