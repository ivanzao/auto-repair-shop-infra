resource "aws_ssm_parameter" "apigw_api_id" {
  name  = "/auto-repair-shop/${var.environment}/apigw/api-id"
  type  = "String"
  value = aws_apigatewayv2_api.this.id
}

resource "aws_ssm_parameter" "apigw_vpc_link_id" {
  name  = "/auto-repair-shop/${var.environment}/apigw/vpc-link-id"
  type  = "String"
  value = aws_apigatewayv2_vpc_link.this.id
}

resource "aws_ssm_parameter" "apigw_execution_arn" {
  name  = "/auto-repair-shop/${var.environment}/apigw/execution-arn"
  type  = "String"
  value = aws_apigatewayv2_api.this.execution_arn
}

resource "aws_ssm_parameter" "apigw_endpoint" {
  name  = "/auto-repair-shop/${var.environment}/apigw/endpoint"
  type  = "String"
  value = aws_apigatewayv2_stage.default.invoke_url
}

resource "aws_ssm_parameter" "apigw_private_listener_arn" {
  name  = "/auto-repair-shop/${var.environment}/apigw/private-listener-arn"
  type  = "String"
  value = aws_lb_listener.order.arn
}

resource "aws_ssm_parameter" "app_target_group_arn" {
  name  = "/auto-repair-shop/${var.environment}/alb/app-target-group-arn"
  type  = "String"
  value = aws_lb_target_group.order.arn
}

resource "aws_ssm_parameter" "service_target_group_arn" {
  for_each = local.services

  name  = "/auto-repair-shop/${var.environment}/alb/${each.key}-target-group-arn"
  type  = "String"
  value = aws_lb_target_group.service[each.key].arn
}

resource "aws_ssm_parameter" "node_port" {
  for_each = local.node_ports

  name  = "/auto-repair-shop/${var.environment}/${each.key}/node-port"
  type  = "String"
  value = tostring(each.value)
}
