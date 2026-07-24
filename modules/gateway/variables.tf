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

variable "http_services" {
  description = "Serviços HTTP e seus ports NLB, keyed por nome de serviço"
  type = map(object({
    node_port     = number
    listener_port = number
  }))
}

variable "lambda_placeholder_image" {
  description = "Placeholder Lambda image used at create time; app CI overrides the real image via update-function-code (image_uri is ignored)."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager entry holding DB connection details. Passed as DB_SECRET_ID env var to the login Lambda."
  type        = string
}
