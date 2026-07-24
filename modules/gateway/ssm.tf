resource "aws_ssm_parameter" "apigw_endpoint" {
  name  = "/auto-repair-shop/${var.environment}/apigw/endpoint"
  type  = "String"
  value = aws_apigatewayv2_stage.default.invoke_url
}
