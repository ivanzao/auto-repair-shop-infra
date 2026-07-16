variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for ALB controller configuration"
  type        = string
}

variable "caller_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "s3_bucket_prefix" {
  description = "Prefix for observability S3 buckets (default uses cluster name)"
  type        = string
  default     = ""
}

variable "rds_endpoint" {
  description = "RDS Postgres endpoint (used by Grafana for state persistence)"
  type        = string
}

variable "rds_port" {
  description = "RDS Postgres port"
  type        = number
  default     = 5432
}

variable "grafana_db_name" {
  description = "PostgreSQL database name for Grafana. Empty = derive from environment."
  type        = string
  default     = ""
}

variable "grafana_db_user" {
  description = "PostgreSQL role name for Grafana. Empty = derive from environment."
  type        = string
  default     = ""
}

variable "grafana_db_password" {
  description = "Grafana DB role password (hardcoded per ADR-002)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin UI password (hardcoded per ADR-002)"
  type        = string
  default     = "admin"
}

variable "db_master_password" {
  description = "RDS Postgres master user password (used by DB init Job to create roles/dbs)"
  type        = string
  sensitive   = true
}

variable "db_order_app_password" {
  description = "Order service DB role password"
  type        = string
  sensitive   = true
}

variable "order_db_name" {
  description = "Order service database name (from module.rds output)"
  type        = string
}

variable "order_db_role" {
  description = "Order service database role (from module.rds output)"
  type        = string
}

variable "rds_billing_endpoint" {
  description = "Endpoint da instância RDS do billing service"
  type        = string
}

variable "db_billing_app_password" {
  description = "Senha do usuário de aplicação do billing service"
  type        = string
  sensitive   = true
}

variable "billing_db_name" {
  description = "Billing service database name (from module.rds_billing output)"
  type        = string
}

variable "billing_db_role" {
  description = "Billing service database role (from module.rds_billing output)"
  type        = string
}
