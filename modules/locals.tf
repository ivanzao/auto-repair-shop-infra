locals {
  cluster_name = "auto-repair-shop-${var.environment}-cluster"

  db_app_passwords = {
    order   = var.db_order_app_password
    billing = var.db_billing_app_password
    user    = var.db_user_app_password
  }
}
