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

variable "lambda_image_base" {
  description = "Base ECR path for Lambda images, from modules/registry (lambda_image_base output)."
  type        = string
}
