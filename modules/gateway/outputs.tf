output "api_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.this.id
}

output "vpc_link_id" {
  description = "VPC Link ID"
  value       = aws_apigatewayv2_vpc_link.this.id
}

output "execution_arn" {
  description = "API Gateway execution ARN (used in Lambda permissions)"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "endpoint" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "private_listener_arn" {
  description = "Private NLB listener ARN used as API Gateway VPC Link integration URI"
  value       = aws_lb_listener.order.arn
}

output "app_target_group_name" {
  description = "Deterministic app target group name used by Kubernetes TargetGroupBinding"
  value       = aws_lb_target_group.order.name
}

output "app_target_group_arn" {
  description = "App target group ARN consumed by Kubernetes TargetGroupBinding (CRD requires ARN, not name)"
  value       = aws_lb_target_group.order.arn
}
