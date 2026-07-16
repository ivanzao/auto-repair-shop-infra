resource "aws_ssm_parameter" "sns_events_topic_arn" {
  name  = "/auto-repair-shop/${var.environment}/sns/events-topic-arn"
  type  = "String"
  value = aws_sns_topic.events.arn
}

resource "aws_ssm_parameter" "sqs_email_queue_arn" {
  name  = "/auto-repair-shop/${var.environment}/sqs/email-queue-arn"
  type  = "String"
  value = aws_sqs_queue.email.arn
}

resource "aws_ssm_parameter" "topic_arn" {
  for_each = local.saga_services

  name  = "/auto-repair-shop/${var.environment}/sns/${each.key}-events-topic-arn"
  type  = "String"
  value = aws_sns_topic.saga[each.key].arn
}

resource "aws_ssm_parameter" "queue_url" {
  for_each = local.saga_services

  name  = "/auto-repair-shop/${var.environment}/sqs/${each.key}-queue-url"
  type  = "String"
  value = aws_sqs_queue.queue[each.key].url
}
