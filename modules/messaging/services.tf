locals {
  services = var.services

  subscriptions = {
    for pair in setproduct(tolist(var.services), tolist(var.services)) :
    "${pair[0]}-from-${pair[1]}" => { queue = pair[0], topic = pair[1] }
    if pair[0] != pair[1]
  }
}

resource "aws_sns_topic" "service" {
  for_each = local.services
  name     = "auto-repair-shop-${each.key}-events-${var.environment}"
}

resource "aws_sqs_queue" "queue_dlq" {
  for_each                  = local.services
  name                      = "auto-repair-shop-${each.key}-queue-dlq-${var.environment}"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "queue" {
  for_each                   = local.services
  name                       = "auto-repair-shop-${each.key}-queue-${var.environment}"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.queue_dlq[each.key].arn
    maxReceiveCount     = 3
  })
}

resource "aws_sns_topic_subscription" "service" {
  for_each = local.subscriptions

  topic_arn            = aws_sns_topic.service[each.value.topic].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.queue[each.value.queue].arn
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "billing_to_email" {
  topic_arn            = aws_sns_topic.service["billing"].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.email.arn
  raw_message_delivery = false

  filter_policy_scope = "MessageAttributes"
  filter_policy = jsonencode({
    eventType = ["QuoteEmailRequested", "QuoteApproved"]
  })
}

data "aws_iam_policy_document" "queue" {
  for_each = local.services

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.queue[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [for s in local.services : aws_sns_topic.service[s].arn if s != each.key]
    }
  }
}

resource "aws_sqs_queue_policy" "queue" {
  for_each  = local.services
  queue_url = aws_sqs_queue.queue[each.key].id
  policy    = data.aws_iam_policy_document.queue[each.key].json
}
