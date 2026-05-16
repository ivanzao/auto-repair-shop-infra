variable "environment" {
  description = "Environment name"
  type        = string
}

variable "db_identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "db_master_username" {
  description = "Master database username"
  type        = string
}

variable "db_master_password" {
  description = "Master database password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID for the RDS subnet group and security group"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "eks_cluster_sg_id" {
  description = "EKS cluster security group ID — allows runner pods to reach the DB"
  type        = string
}

variable "lambda_sg_id" {
  description = "Lambda security group ID allowed to reach the database"
  type        = string
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy — set false for prod"
  type        = bool
  default     = false
}

variable "secret_recovery_window_days" {
  description = "Days before a deleted Secrets Manager secret is permanently removed"
  type        = number
  default     = 7
}
