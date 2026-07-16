output "lambda_image_base" {
  description = "Base ECR path (GHCR via pull-through cache) that Lambda image_uri values prepend"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_pull_through_cache_rule.ghcr.ecr_repository_prefix}/${var.ghcr_username}"
}
