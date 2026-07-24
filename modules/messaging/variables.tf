variable "environment" {
  description = "Environment name (e.g. prod, hml)"
  type        = string
}

variable "services" {
  description = "Nomes dos serviços que participam do event bus (topic + queue + subscriptions full-mesh)"
  type        = set(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where the email Lambda runs (VPC config)."
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Security group ID applied to the email Lambda ENIs."
  type        = string
}

variable "lambda_placeholder_image" {
  description = "Placeholder Lambda image used at create time; app CI overrides the real image via update-function-code (image_uri is ignored)."
  type        = string
}
