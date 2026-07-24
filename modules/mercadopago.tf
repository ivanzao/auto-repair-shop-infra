resource "aws_secretsmanager_secret" "mercadopago" {
  name                    = "auto-repair-shop/${var.environment}/mercadopago"
  description             = "Credenciais do Mercado Pago para o billing service (${var.environment}). Valor gerenciado pelo CI do repo do billing."
  recovery_window_in_days = 0
}
