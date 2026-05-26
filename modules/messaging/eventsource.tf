resource "aws_lambda_event_source_mapping" "email" {
  event_source_arn        = aws_sqs_queue.email.arn
  function_name           = aws_lambda_function.email.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}
