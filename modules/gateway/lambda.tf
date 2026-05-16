# Lambdas for the HTTP edge (login + authorizer).
#
# Created as Container image (package_type = "Image") referencing the ECR
# Pull Through Cache URL that maps to ghcr.io.
#
# BOOTSTRAP REQUIREMENT: the PTC cache MUST be warm before this terraform
# resource creates. The lambdas pipeline performs `docker pull` against the
# PTC URL right after pushing to GHCR; that pull warms the cache. Bootstrap
# order: target-apply module.registry -> lambdas pipeline -> full terraform apply.
#
# Day-to-day after bootstrap: lambdas pipeline pushes new image + warms PTC +
# calls update-function-code + update-function-configuration to refresh code
# and env vars. lifecycle ignore_changes keeps terraform out of that loop.

resource "aws_lambda_function" "login" {
  function_name = "auto-repair-shop-login-${var.environment}"
  package_type  = "Image"
  image_uri     = "${local.ghcr_ecr_base}/auto-repair-shop-login:latest"
  role          = data.aws_iam_role.lab_role.arn
  architectures = ["arm64"]
  timeout       = 15
  memory_size   = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      DB_SECRET_ID = var.db_secret_arn
      JWT_HMAC     = "PLACEHOLDER"
    }
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [image_uri, environment]
  }
}

resource "aws_lambda_function" "authorizer" {
  function_name = "auto-repair-shop-authorizer-${var.environment}"
  package_type  = "Image"
  image_uri     = "${local.ghcr_ecr_base}/auto-repair-shop-authorizer:latest"
  role          = data.aws_iam_role.lab_role.arn
  architectures = ["arm64"]
  timeout       = 5
  memory_size   = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      JWT_HMAC = "PLACEHOLDER"
    }
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [image_uri, environment]
  }
}
