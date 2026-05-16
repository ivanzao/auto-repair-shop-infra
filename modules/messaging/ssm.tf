resource "aws_ssm_parameter" "sns_events_topic_arn" {
  name  = "/auto-repair-shop/${var.environment}/sns/events-topic-arn"
  type  = "String"
  value = aws_sns_topic.events.arn

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sqs_email_queue_arn" {
  name  = "/auto-repair-shop/${var.environment}/sqs/email-queue-arn"
  type  = "String"
  value = aws_sqs_queue.email.arn

  tags = local.common_tags
}
