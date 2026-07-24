locals {
  # Integrations HTTP_PROXY via VPC Link. `protected` injeta os headers de
  # identidade vindos do authorizer; as públicas não passam pelo authorizer.
  # A `login` (Lambda AWS_PROXY) não entra aqui — é outra forma de integração.
  gateway_integrations = {
    order          = { listener_arn = aws_lb_listener.order.arn, protected = true }
    order_public   = { listener_arn = aws_lb_listener.order.arn, protected = false }
    billing        = { listener_arn = aws_lb_listener.service["billing"].arn, protected = true }
    billing_public = { listener_arn = aws_lb_listener.service["billing"].arn, protected = false }
    execution      = { listener_arn = aws_lb_listener.service["execution"].arn, protected = true }
  }
}

resource "aws_apigatewayv2_integration" "svc" {
  for_each = local.gateway_integrations

  api_id                 = aws_apigatewayv2_api.this.id
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  connection_type        = "VPC_LINK"
  integration_method     = "ANY"
  integration_type       = "HTTP_PROXY"
  integration_uri        = each.value.listener_arn
  payload_format_version = "1.0"

  request_parameters = each.value.protected ? {
    "overwrite:header.X-User-Id"   = "$context.authorizer.userId"
    "overwrite:header.X-User-Role" = "$context.authorizer.role"
    } : {
    "remove:header.X-User-Id"   = "''"
    "remove:header.X-User-Role" = "''"
  }
}
