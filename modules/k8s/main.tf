locals {
  lab_role_arn    = "arn:aws:iam::${var.caller_account_id}:role/LabRole"
  app_namespace   = "auto-repair-shop-${var.environment}"
  grafana_db_name = var.grafana_db_name != "" ? var.grafana_db_name : "grafana_${var.environment}"
  grafana_db_user = var.grafana_db_user != "" ? var.grafana_db_user : "grafana_${var.environment}"
  common_tags = {
    Environment = var.environment
    Application = "auto-repair-shop"
    ManagedBy   = "terraform"
  }
}

# ─── Namespaces ───────────────────────────────────────────────────────────────

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

# ─── App service account ──────────────────────────────────────────────────────
# AWS Academy doesn't permit iam:AttachRolePolicy on LabRole. The pod inherits
# credentials from the node IAM (LabRole + VocLabPolicy*), so SNS publish works
# without an explicit IRSA policy attachment.

resource "kubernetes_service_account" "app" {
  metadata {
    name      = "auto-repair-shop"
    namespace = local.app_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = local.lab_role_arn
    }
  }
  depends_on = [kubernetes_namespace.app]
}
