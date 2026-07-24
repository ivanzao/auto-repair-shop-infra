locals {
  cluster_name = "auto-repair-shop-${var.environment}-cluster"

  services = {
    order     = { db = true, dynamo = false, events = true, http = true }
    billing   = { db = true, dynamo = false, events = true, http = true }
    execution = { db = false, dynamo = true, events = true, http = true }
    auth      = { db = true, dynamo = false, events = false, http = false }
  }

  db_services     = { for k, v in local.services : k => v if v.db }
  dynamo_services = { for k, v in local.services : k => v if v.dynamo }
  http_services   = { for k, v in local.services : k => v if v.http }
  event_services  = toset([for k, v in local.services : k if v.events])

  password_by_service = {
    order   = var.db_order_app_password
    billing = var.db_billing_app_password
    auth    = var.db_auth_app_password
  }
  db_app_passwords = { for k, v in local.db_services : k => local.password_by_service[k] }

  http_ports = {
    for idx, name in sort(keys(local.http_services)) : name => {
      node_port     = 30080 + idx
      listener_port = 8080 + idx
    }
  }
}
