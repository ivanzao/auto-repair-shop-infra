output "table_name" {
  description = "DynamoDB table name for the execution service"
  value       = aws_dynamodb_table.execution.name
}

output "table_arn" {
  description = "DynamoDB table ARN for the execution service"
  value       = aws_dynamodb_table.execution.arn
}
