locals {
  lab_role_arn    = "arn:aws:iam::${var.caller_account_id}:role/LabRole"
  app_namespace   = "auto-repair-shop-${var.environment}"
  grafana_db_name = var.grafana_db_name != "" ? var.grafana_db_name : "grafana_${var.environment}"
  grafana_db_user = var.grafana_db_user != "" ? var.grafana_db_user : "grafana_${var.environment}"
}

resource "kubernetes_namespace" "app" {
  metadata {
    name   = local.app_namespace
    labels = { environment = var.environment, app = "auto-repair-shop" }
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name   = "observability"
    labels = { app = "observability" }
  }
}

resource "kubernetes_service_account" "app" {
  for_each = toset(["auto-repair-shop", "auto-repair-shop-billing", "auto-repair-shop-execution"])
  metadata {
    name      = each.value
    namespace = local.app_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = local.lab_role_arn
    }
  }
  depends_on = [kubernetes_namespace.app]
}
