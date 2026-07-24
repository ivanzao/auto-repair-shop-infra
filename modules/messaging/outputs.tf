output "sqs_email_queue_arn" {
  description = "SQS email queue ARN"
  value       = aws_sqs_queue.email.arn
}

output "sqs_email_dlq_arn" {
  description = "SQS email dead-letter queue ARN"
  value       = aws_sqs_queue.email_dlq.arn
}
