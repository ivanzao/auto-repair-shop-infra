output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.eks.cluster_ca
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "VPC ID for the environment"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "lambda_sg_id" {
  description = "Security group ID shared by Lambda functions and VPC Link"
  value       = module.vpc.lambda_sg_id
}

output "rds_endpoints" {
  description = "RDS PostgreSQL endpoint per service, keyed by service name"
  value       = { for name, m in module.rds : name => m.rds_endpoint }
}

output "db_secret_arns" {
  description = "App DB credentials secret ARN per service, keyed by service name"
  value       = { for name, m in module.rds : name => m.secret_arn_app }
}
