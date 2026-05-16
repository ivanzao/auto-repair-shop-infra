variable "environment" {
  description = "Environment name (e.g. prod, hml). Used as ECR PTC prefix suffix and as the secret name suffix."
  type        = string
}

variable "ghcr_username" {
  description = "GHCR username (GitHub user/org) used for image pulls via ECR Pull Through Cache."
  type        = string
}

variable "ghcr_token" {
  description = "GHCR PAT with read:packages used by ECR PTC to pull private images. Stored in Secrets Manager."
  type        = string
  sensitive   = true
}
