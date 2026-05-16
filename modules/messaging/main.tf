data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

locals {
  common_tags = {
    Environment = var.environment
    Application = "auto-repair-shop"
    ManagedBy   = "terraform"
  }

  # ECR PTC URL base that maps to ghcr.io/<owner>
  ghcr_ecr_base = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_prefix}/${var.ghcr_owner}"
}
