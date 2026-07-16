output "vpc_id" {
  description = "VPC ID for the environment"
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
  value       = module.rds["order"].rds_endpoint
}

output "secret_arn_master" {
  description = "ARN of the RDS master credentials secret"
  value       = module.rds["order"].secret_arn_master
}

output "secret_arn_order" {
  description = "ARN of the order service DB credentials secret (host, port, dbname, username, password)"
  value       = module.rds["order"].secret_arn_app
}

output "private_subnet_ids" {
  description = "Private subnet IDs (AZ-a and AZ-b)"
  value       = module.vpc.private_subnet_ids
}

output "lambda_sg_id" {
  description = "Security group ID shared by Lambda functions and VPC Link"
  value       = module.vpc.lambda_sg_id
}
