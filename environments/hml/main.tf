module "infra" {
  source = "../../modules"

  environment   = var.environment
  aws_region    = var.aws_region
  vpc_cidr      = var.vpc_cidr
  node_min_size = var.node_min_size
  node_max_size = var.node_max_size

  db_master_password      = var.db_master_password
  db_order_app_password   = var.db_order_app_password
  db_billing_app_password = var.db_billing_app_password
  db_auth_app_password    = var.db_auth_app_password
  ghcr_token              = var.ghcr_token
}
