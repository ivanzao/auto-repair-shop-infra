resource "aws_sqs_queue" "email_dlq" {
  name                      = "auto-repair-shop-email-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "email" {
  name                       = "auto-repair-shop-email-${var.environment}"
  visibility_timeout_seconds = 180 # 6× Lambda timeout (30s) per AWS recommendation

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_dlq.arn
    maxReceiveCount     = 3
  })
}
