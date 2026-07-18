resource "aws_lambda_function" "email" {
  function_name                  = "auto-repair-shop-email-${var.environment}"
  package_type                   = "Image"
  image_uri                      = var.lambda_placeholder_image
  role                           = local.lab_role_arn
  architectures                  = ["arm64"]
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 10

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      MAILERSEND_TOKEN = "PLACEHOLDER"
      MAIL_FROM        = "PLACEHOLDER"
    }
  }


  lifecycle {
    ignore_changes = [image_uri, environment]
  }
}
