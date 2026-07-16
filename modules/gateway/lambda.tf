resource "aws_lambda_function" "login" {
  function_name = "auto-repair-shop-login-${var.environment}"
  package_type  = "Image"
  image_uri     = "${var.lambda_image_base}/auto-repair-shop-login:latest"
  role          = local.lab_role_arn
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


  lifecycle {
    ignore_changes = [image_uri, environment]
  }
}

resource "aws_lambda_function" "authorizer" {
  function_name = "auto-repair-shop-authorizer-${var.environment}"
  package_type  = "Image"
  image_uri     = "${var.lambda_image_base}/auto-repair-shop-authorizer:latest"
  role          = local.lab_role_arn
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


  lifecycle {
    ignore_changes = [image_uri, environment]
  }
}
