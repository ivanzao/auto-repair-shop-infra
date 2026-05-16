resource "aws_sns_topic_subscription" "sns_to_sqs" {
  topic_arn            = aws_sns_topic.events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.email.arn
  raw_message_delivery = false
}
