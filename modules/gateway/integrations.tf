locals {
  public_routes = merge(
    { for svc in keys(local.services) : "${svc}_health" => {
      service   = svc
      route_key = "GET /${svc}/health"
      overwrite = "/health"
    } },
    { for svc in keys(local.services) : "${svc}_swagger" => {
      service   = svc
      route_key = "GET /${svc}/swagger/{proxy+}"
      overwrite = "/swagger/$request.path.proxy"
    } },
    {
      billing_quote_approve = { service = "billing", route_key = "GET /billing/v1/quotes/approve", overwrite = "/v1/quotes/approve" }
      billing_quote_decline = { service = "billing", route_key = "GET /billing/v1/quotes/decline", overwrite = "/v1/quotes/decline" }
      billing_mp_webhook    = { service = "billing", route_key = "POST /billing/v1/webhooks/mercadopago", overwrite = "/v1/webhooks/mercadopago" }
    }
  )
}

resource "aws_apigatewayv2_integration" "protected" {
  for_each = local.services

  api_id                 = aws_apigatewayv2_api.this.id
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  connection_type        = "VPC_LINK"
  integration_method     = "ANY"
  integration_type       = "HTTP_PROXY"
  integration_uri        = aws_lb_listener.service[each.key].arn
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path"               = "/$request.path.proxy"
    "overwrite:header.X-User-Id"   = "$context.authorizer.userId"
    "overwrite:header.X-User-Role" = "$context.authorizer.role"
  }
}

resource "aws_apigatewayv2_integration" "public" {
  for_each = local.public_routes

  api_id                 = aws_apigatewayv2_api.this.id
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  connection_type        = "VPC_LINK"
  integration_method     = "ANY"
  integration_type       = "HTTP_PROXY"
  integration_uri        = aws_lb_listener.service[each.value.service].arn
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path"            = each.value.overwrite
    "remove:header.X-User-Id"   = "''"
    "remove:header.X-User-Role" = "''"
  }
}
