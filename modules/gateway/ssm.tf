resource "aws_ssm_parameter" "apigw_api_id" {
  name  = "/auto-repair-shop/${var.environment}/apigw/api-id"
  type  = "String"
  value = aws_apigatewayv2_api.this.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "apigw_vpc_link_id" {
  name  = "/auto-repair-shop/${var.environment}/apigw/vpc-link-id"
  type  = "String"
  value = aws_apigatewayv2_vpc_link.this.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "apigw_execution_arn" {
  name  = "/auto-repair-shop/${var.environment}/apigw/execution-arn"
  type  = "String"
  value = aws_apigatewayv2_api.this.execution_arn

  tags = local.common_tags
}

resource "aws_ssm_parameter" "apigw_endpoint" {
  name  = "/auto-repair-shop/${var.environment}/apigw/endpoint"
  type  = "String"
  value = aws_apigatewayv2_stage.default.invoke_url

  tags = local.common_tags
}

resource "aws_ssm_parameter" "apigw_private_listener_arn" {
  name  = "/auto-repair-shop/${var.environment}/apigw/private-listener-arn"
  type  = "String"
  value = aws_lb_listener.app.arn

  tags = local.common_tags
}

resource "aws_ssm_parameter" "app_target_group_arn" {
  name  = "/auto-repair-shop/${var.environment}/alb/app-target-group-arn"
  type  = "String"
  value = aws_lb_target_group.app.arn

  tags = local.common_tags
}
