variable "environment" {
  description = "Environment name (hml, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "db_master_password" {
  description = "Master database password"
  type        = string
  sensitive   = true
}

variable "db_order_app_password" {
  description = "Order service DB user password"
  type        = string
  sensitive   = true
}

variable "db_billing_app_password" {
  description = "Billing service DB user password"
  type        = string
  sensitive   = true
}

variable "db_auth_app_password" {
  description = "Identity/auth (login) DB user password"
  type        = string
  sensitive   = true
}

variable "ghcr_token" {
  description = "GHCR PAT used by ECR Pull Through Cache"
  type        = string
  sensitive   = true
}
