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

variable "app_node_port" {
  description = "NodePort exposed by the app Kubernetes Service; NLB target group routes to this port on the EC2 instances"
  type        = number
  default     = 30080
}

variable "ecr_repository_prefix" {
  description = "ECR Pull Through Cache prefix (e.g. ghcr-prod). Used to build Lambda image URIs that resolve to GHCR transparently."
  type        = string
}

variable "ghcr_owner" {
  description = "GHCR owner/org segment of the image path (e.g. ivanzao)."
  type        = string
  default     = "ivanzao"
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager entry holding DB connection details. Passed as DB_SECRET_ID env var to the login Lambda."
  type        = string
}

variable "aws_region" {
  description = "AWS region (used to build ECR PTC URLs)."
  type        = string
  default     = "us-east-1"
}
