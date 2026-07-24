resource "aws_ssm_parameter" "topic_arn" {
  for_each = local.services

  name  = "/auto-repair-shop/${var.environment}/sns/${each.key}-events-topic-arn"
  type  = "String"
  value = aws_sns_topic.service[each.key].arn
}

resource "aws_ssm_parameter" "queue_url" {
  for_each = local.services

  name  = "/auto-repair-shop/${var.environment}/sqs/${each.key}-queue-url"
  type  = "String"
  value = aws_sqs_queue.queue[each.key].url
}
