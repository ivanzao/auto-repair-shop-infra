variable "environment" {
  description = "Environment name (e.g. prod, hml)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where the email Lambda runs (VPC config)."
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Security group ID applied to the email Lambda ENIs."
  type        = string
}

variable "ecr_repository_prefix" {
  description = "ECR Pull Through Cache prefix (e.g. ghcr-prod). Used to build the email Lambda image URI."
  type        = string
}

variable "ghcr_owner" {
  description = "GHCR owner segment in the image path (e.g. ivanzao)."
  type        = string
  default     = "ivanzao"
}

variable "aws_region" {
  description = "AWS region used to build ECR PTC URLs."
  type        = string
  default     = "us-east-1"
}
