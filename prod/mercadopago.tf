# Shell do secret: a infra provê o "repositório" e o contrato (ARN via SSM);
# o valor (access_token, webhook_secret) é populado pelo CI do repo do billing
# via aws secretsmanager put-secret-value, com origem nos GitHub secrets de lá.
resource "aws_secretsmanager_secret" "mercadopago" {
  name                    = "auto-repair-shop/${var.environment}/mercadopago"
  description             = "Credenciais do Mercado Pago para o billing service (${var.environment}). Valor gerenciado pelo CI do repo do billing."
  recovery_window_in_days = 0
}

resource "aws_ssm_parameter" "mercadopago_secret_arn" {
  name  = "/auto-repair-shop/${var.environment}/billing/mercadopago-secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.mercadopago.arn
}
