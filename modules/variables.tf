variable "environment" {
  description = "Environment name (hml, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
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

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.14"
}

variable "db_master_username" {
  description = "Master database username"
  type        = string
  default     = "postgres"
}

variable "db_master_password" {
  description = "Master database password"
  type        = string
  sensitive   = true
}

variable "db_order_app_password" {
  description = "Application database user password"
  type        = string
  sensitive   = true
}

variable "db_billing_app_password" {
  description = "Senha do usuário de aplicação do billing service"
  type        = string
  sensitive   = true
}

variable "db_user_app_password" {
  description = "Senha do usuário de aplicação do banco de identidade (login lambda)"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin UI password (hardcoded per ADR-002)"
  type        = string
  default     = "admin"
}

variable "ghcr_username" {
  description = "GHCR username used for ECR Pull Through Cache. Default matches the org that publishes Lambda images."
  type        = string
  default     = "ivanzao"
}

variable "ghcr_token" {
  description = "GHCR PAT (read:packages) used by ECR PTC. Sourced from TF_VAR_ghcr_token in CI."
  type        = string
  sensitive   = true
}
