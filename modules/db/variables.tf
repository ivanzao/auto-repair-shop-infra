variable "environment" {
  description = "Environment name"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS instance hostname (used in the app credentials secret)"
  type        = string
}

variable "rds_port" {
  description = "RDS instance port"
  type        = number
}

variable "db_app_password" {
  description = "Application database user password"
  type        = string
  sensitive   = true
}

variable "secret_recovery_window_days" {
  description = "Days before a deleted Secrets Manager secret is permanently removed"
  type        = number
  default     = 7
}
