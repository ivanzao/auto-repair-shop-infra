# Email Lambda: SQS consumer that sends quote emails via MailerSend.
#
# Same pattern as modules/gateway/lambda.tf: Container image via ECR PTC,
# requires PTC cache warm before creation. lambdas pipeline owns runtime
# lifecycle (image_uri + environment) via update-function-code +
# update-function-configuration after each push.

resource "aws_lambda_function" "email" {
  function_name                  = "auto-repair-shop-email-${var.environment}"
  package_type                   = "Image"
  image_uri                      = "${local.ghcr_ecr_base}/auto-repair-shop-email:latest"
  role                           = data.aws_iam_role.lab_role.arn
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

  tags = local.common_tags

  lifecycle {
    ignore_changes = [image_uri, environment]
  }
}
