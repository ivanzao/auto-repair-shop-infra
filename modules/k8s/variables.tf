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

variable "app_databases" {
  description = "Per-service DB connection info (endpoint, role, db name) keyed by service name, consumed by the DB init Jobs"
  type = map(object({
    endpoint = string
    role     = string
    db       = string
  }))
}

variable "app_db_passwords" {
  description = "Per-service DB role passwords keyed by service name"
  type        = map(string)
  sensitive   = true
}
