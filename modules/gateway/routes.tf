resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.this.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  authorizer_result_ttl_in_seconds  = 300
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "jwt-authorizer-${var.environment}"
}

resource "aws_lambda_permission" "apigw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.jwt.id}"
}

resource "aws_apigatewayv2_integration" "login" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.login.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_lambda_permission" "apigw_login" {
  statement_id  = "AllowAPIGatewayInvokeLogin"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "order_protected" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.svc["order"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "quote_approve" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /v1/orders/quote/approve"
  target    = "integrations/${aws_apigatewayv2_integration.svc["order_public"].id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.svc["order_public"].id}"
}

resource "aws_apigatewayv2_route" "swagger_root" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /swagger"
  target    = "integrations/${aws_apigatewayv2_integration.svc["order_public"].id}"
}

resource "aws_apigatewayv2_route" "swagger_proxy" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /swagger/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.svc["order_public"].id}"
}

resource "aws_apigatewayv2_route" "quote_decline" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /v1/orders/quote/decline"
  target    = "integrations/${aws_apigatewayv2_integration.svc["order_public"].id}"
}
