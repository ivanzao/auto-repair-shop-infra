locals {
  saga_services = toset(["order", "billing", "execution"])

  saga_subscriptions = {
    order-from-billing     = { queue = "order", topic = "billing" }
    order-from-execution   = { queue = "order", topic = "execution" }
    billing-from-order     = { queue = "billing", topic = "order" }
    billing-from-execution = { queue = "billing", topic = "execution" }
    execution-from-order   = { queue = "execution", topic = "order" }
    execution-from-billing = { queue = "execution", topic = "billing" }
  }
}

resource "aws_sns_topic" "saga" {
  for_each = local.saga_services
  name     = "auto-repair-shop-${each.key}-events-${var.environment}"
}

resource "aws_sqs_queue" "queue_dlq" {
  for_each                  = local.saga_services
  name                      = "auto-repair-shop-${each.key}-queue-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 dias
}

resource "aws_sqs_queue" "queue" {
  for_each                   = local.saga_services
  name                       = "auto-repair-shop-${each.key}-queue-${var.environment}"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.queue_dlq[each.key].arn
    maxReceiveCount     = 3
  })
}

resource "aws_sns_topic_subscription" "saga" {
  for_each = local.saga_subscriptions

  topic_arn            = aws_sns_topic.saga[each.value.topic].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.queue[each.value.queue].arn
  raw_message_delivery = true
}

# Lambda de email passa a ouvir também o tópico do billing (dono do fluxo de
# orçamento na Fase 4). A assinatura antiga no tópico legado permanece até o
# cleanup final da migração.
resource "aws_sns_topic_subscription" "billing_to_email" {
  topic_arn            = aws_sns_topic.saga["billing"].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.email.arn
  raw_message_delivery = false

  filter_policy_scope = "MessageAttributes"
  filter_policy = jsonencode({
    eventType = ["QuoteEmailRequested"]
  })
}

data "aws_iam_policy_document" "queue" {
  for_each = local.saga_services

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
      values   = [for s in local.saga_services : aws_sns_topic.saga[s].arn if s != each.key]
    }
  }
}

resource "aws_sqs_queue_policy" "queue" {
  for_each  = local.saga_services
  queue_url = aws_sqs_queue.queue[each.key].id
  policy    = data.aws_iam_policy_document.queue[each.key].json
}
