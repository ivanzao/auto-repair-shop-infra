resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/auto-repair-shop/prod/eks/cluster-name"
  type  = "String"
  value = module.eks.cluster_name
}

resource "aws_ssm_parameter" "db_secret_arn" {
  name        = "/auto-repair-shop/prod/db/secret-arn"
  type        = "String"
  value       = module.rds.secret_arn_app
  description = "ARN do Secrets Manager com credenciais do app (JSON: host, port, dbname, username, password)"
}
