output "ecr_repository_prefix" {
  description = "PTC prefix that consumers prepend to GHCR paths to form ECR URLs (e.g. ghcr-prod)"
  value       = aws_ecr_pull_through_cache_rule.ghcr.ecr_repository_prefix
}

output "ecr_credential_arn" {
  description = "ARN of the Secrets Manager entry holding GHCR credentials"
  value       = aws_secretsmanager_secret.ghcr.arn
}
