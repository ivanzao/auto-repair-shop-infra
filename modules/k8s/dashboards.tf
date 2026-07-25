locals {
  grafana_folder = "Auto Repair Shop"
}

resource "kubernetes_config_map_v1" "dashboard_orders_operations" {
  metadata {
    name      = "dashboard-orders-operations"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = local.grafana_folder
    }
  }

  data = {
    "orders-operations.json" = file("${path.module}/dashboards/orders-operations.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "dashboard_apm" {
  metadata {
    name      = "dashboard-apm"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = local.grafana_folder
    }
  }

  data = {
    "apm.json" = file("${path.module}/dashboards/apm.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "dashboard_errors_integrations" {
  metadata {
    name      = "dashboard-errors-integrations"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = local.grafana_folder
    }
  }

  data = {
    "errors-integrations.json" = file("${path.module}/dashboards/errors-integrations.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "dashboard_execution_saga" {
  metadata {
    name      = "dashboard-execution-saga"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = local.grafana_folder
    }
  }

  data = {
    "execution-saga.json" = file("${path.module}/dashboards/execution-saga.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
