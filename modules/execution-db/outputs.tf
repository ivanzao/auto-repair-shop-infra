output "table_names" {
  description = "DynamoDB table name per service, keyed by service name"
  value       = { for k, t in aws_dynamodb_table.service : k => t.name }
}

output "table_arns" {
  description = "DynamoDB table ARN per service, keyed by service name"
  value       = { for k, t in aws_dynamodb_table.service : k => t.arn }
}
