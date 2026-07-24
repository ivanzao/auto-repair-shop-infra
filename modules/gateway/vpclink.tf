resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "auto-repair-shop-${var.environment}"
  security_group_ids = [var.lambda_sg_id]
  subnet_ids         = var.private_subnet_ids
}
