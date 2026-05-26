output "vpc_id" {
  description = "VPC ID for the prod environment"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS PostgreSQL hostname (no port)"
  value       = module.rds.rds_endpoint
}

output "secret_arn_master" {
  description = "ARN of the RDS master credentials secret"
  value       = module.rds.secret_arn_master
}

output "secret_arn_app" {
  description = "ARN of the app credentials secret (host, port, dbname, username, password)"
  value       = module.db.secret_arn_app
}

output "arc_runner_set_name" {
  description = "ARC runner scale set name — use as runs-on label in GitHub Actions workflows"
  value       = module.k8s.arc_runner_set_name
}

output "private_subnet_ids" {
  description = "Private subnet IDs (AZ-a and AZ-b)"
  value       = module.vpc.private_subnet_ids
}

output "lambda_sg_id" {
  description = "Security group ID shared by Lambda functions and VPC Link"
  value       = module.vpc.lambda_sg_id
}
