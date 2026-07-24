resource "aws_apigatewayv2_route" "billing_protected" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/quotes/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.svc["billing"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "billing_quotes_collection" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/quotes"
  target             = "integrations/${aws_apigatewayv2_integration.svc["billing"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "billing_quote_approve" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /v1/quotes/approve"
  target    = "integrations/${aws_apigatewayv2_integration.svc["billing_public"].id}"
}

resource "aws_apigatewayv2_route" "billing_quote_decline" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /v1/quotes/decline"
  target    = "integrations/${aws_apigatewayv2_integration.svc["billing_public"].id}"
}

resource "aws_apigatewayv2_route" "billing_mp_webhook" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /v1/webhooks/mercadopago"
  target    = "integrations/${aws_apigatewayv2_integration.svc["billing_public"].id}"
}

resource "aws_apigatewayv2_route" "execution_protected" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/executions/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.svc["execution"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "execution_collection" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/executions"
  target             = "integrations/${aws_apigatewayv2_integration.svc["execution"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "parts_protected" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/parts/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.svc["execution"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "parts_collection" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /v1/parts"
  target             = "integrations/${aws_apigatewayv2_integration.svc["execution"].id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "CUSTOM"
}
