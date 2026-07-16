variable "environment" {
  description = "Environment name (e.g. prod, hml)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the VPC Link"
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Security group ID shared by Lambda functions; applied to the VPC Link"
  type        = string
}

variable "eks_cluster_sg_id" {
  description = "EKS cluster security group ID that receives traffic from the app NLB"
  type        = string
}

variable "node_group_asg_names" {
  description = "EKS node group Auto Scaling Group names attached to the app NLB target group"
  type        = list(string)
}

variable "lambda_image_base" {
  description = "Base ECR path for Lambda images, from modules/registry (lambda_image_base output)."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager entry holding DB connection details. Passed as DB_SECRET_ID env var to the login Lambda."
  type        = string
}
