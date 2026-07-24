resource "aws_ssm_parameter" "apigw_endpoint" {
  name  = "/auto-repair-shop/${var.environment}/apigw/endpoint"
  type  = "String"
  value = aws_apigatewayv2_stage.default.invoke_url
}

resource "aws_ssm_parameter" "node_port" {
  for_each = local.node_ports

  name  = "/auto-repair-shop/${var.environment}/${each.key}/node-port"
  type  = "String"
  value = tostring(each.value)
}
