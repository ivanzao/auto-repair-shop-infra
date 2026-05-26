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

# App proxy: ANY /v1/{proxy+} -> VPC Link -> NLB listener -> NodePort -> pods.
# Protected by the JWT authorizer. The authorizer injects userId and role
# as headers the Kotlin app can read directly.
resource "aws_apigatewayv2_integration" "app" {
  api_id                 = aws_apigatewayv2_api.this.id
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  connection_type        = "VPC_LINK"
  integration_method     = "ANY"
  integration_type       = "HTTP_PROXY"
  integration_uri        = aws_lb_listener.app.arn
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:header.X-User-Id"   = "$context.authorizer.userId"
    "overwrite:header.X-User-Role" = "$context.authorizer.role"
  }
}

# Public app integration: same VPC Link / NLB target as the protected one, but
# without authorizer header injection. Used by routes that customers reach
# without a JWT (e.g. quote approve/decline links emailed to them).
resource "aws_apigatewayv2_integration" "app_public" {
  api_id                 = aws_apigatewayv2_api.this.id
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  connection_type        = "VPC_LINK"
  integration_method     = "ANY"
  integration_type       = "HTTP_PROXY"
  integration_uri        = aws_lb_listener.app.arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "app_protected" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.app.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

# Public quote approval routes — customer clicks the link from the email
# without any JWT. More specific than ANY /v1/{proxy+}, so API Gateway HTTP
# matches these first and bypasses the authorizer.
resource "aws_apigatewayv2_route" "quote_approve" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /v1/orders/quote/approve"
  target    = "integrations/${aws_apigatewayv2_integration.app_public.id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.app_public.id}"
}

# Swagger UI — Ktor exposes the UI at /swagger and its assets at /swagger/{proxy+}.
# These routes are public (no JWT) so developers can browse the API docs without a token.
resource "aws_apigatewayv2_route" "swagger_root" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /swagger"
  target    = "integrations/${aws_apigatewayv2_integration.app_public.id}"
}

resource "aws_apigatewayv2_route" "swagger_proxy" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /swagger/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.app_public.id}"
}

resource "aws_apigatewayv2_route" "quote_decline" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /v1/orders/quote/decline"
  target    = "integrations/${aws_apigatewayv2_integration.app_public.id}"
}
