resource "helm_release" "otel_operator" {
  name             = "opentelemetry-operator"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-operator"
  version          = "0.75.0"
  namespace        = "observability"
  create_namespace = false
  timeout          = 300

  values = [file("${path.module}/helm-values/base/otel-operator.yaml")]

  # AlbController has a mutating webhook on Services. If it isn't ready when
  # the OTel operator chart creates its webhook Service, the chart install
  # fails on first-time cluster bootstrap.
  depends_on = [
    kubernetes_namespace.observability,
    helm_release.alb_controller,
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "85.1.3"
  namespace        = "observability"
  create_namespace = false
  timeout          = 1200

  # Grafana depends on grafana_<env> Postgres user, which is created by
  # module.db in init-database-hml (stage 2 on the ARC runner). Stage 1 deploys
  # this chart before that user exists, so Grafana CrashLoops. wait=false lets
  # terraform mark the release deployed even with unready pods; Grafana
  # auto-recovers once stage 2 finishes.
  wait = false

  values = [
    templatefile("${path.module}/helm-values/base/kube-prometheus-stack.yaml", {
      grafana_admin_password = var.grafana_admin_password
      rds_endpoint           = var.rds_endpoint
      rds_port               = var.rds_port
      grafana_db_name        = local.grafana_db_name
      grafana_db_user        = local.grafana_db_user
      grafana_db_password    = var.grafana_db_password
    }),
    file("${path.module}/helm-values/${var.environment}/kube-prometheus-stack.yaml"),
  ]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_job_v1.db_init,
  ]
}

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = "6.55.0"
  namespace        = "observability"
  create_namespace = false
  timeout          = 600

  # Pod budget tight on first deploy; allow async pod readiness.
  wait = false

  values = [
    templatefile("${path.module}/helm-values/base/loki.yaml", {
      aws_region  = var.aws_region
      loki_bucket = aws_s3_bucket.loki.id
    }),
    file("${path.module}/helm-values/${var.environment}/loki.yaml"),
  ]

  depends_on = [
    helm_release.kube_prometheus_stack,
    aws_s3_bucket.loki,
  ]
}

resource "helm_release" "tempo" {
  name             = "tempo"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo"
  version          = "1.24.4"
  namespace        = "observability"
  create_namespace = false
  timeout          = 300

  wait = false

  values = [
    templatefile("${path.module}/helm-values/base/tempo.yaml", {
      aws_region   = var.aws_region
      tempo_bucket = aws_s3_bucket.tempo.id
    }),
    file("${path.module}/helm-values/${var.environment}/tempo.yaml"),
  ]

  depends_on = [
    helm_release.loki,
    aws_s3_bucket.tempo,
  ]
}

resource "helm_release" "alloy_daemonset" {
  name             = "alloy-daemonset"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = "1.8.1"
  namespace        = "observability"
  create_namespace = false
  timeout          = 300

  wait = false

  values = [file("${path.module}/helm-values/base/alloy-daemonset.yaml")]

  depends_on = [
    helm_release.loki,
    helm_release.tempo,
  ]
}

resource "helm_release" "alloy_gateway" {
  name             = "alloy-gateway"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = "1.8.1"
  namespace        = "observability"
  create_namespace = false

  wait    = false
  timeout = 300

  values = [file("${path.module}/helm-values/base/alloy-gateway.yaml")]

  depends_on = [
    helm_release.loki,
    helm_release.tempo,
  ]
}

resource "helm_release" "blackbox_exporter" {
  name             = "blackbox-exporter"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-blackbox-exporter"
  version          = "8.17.0"
  namespace        = "observability"
  create_namespace = false
  timeout          = 300

  values = [
    file("${path.module}/helm-values/base/blackbox-exporter.yaml"),
    file("${path.module}/helm-values/${var.environment}/blackbox-exporter.yaml"),
  ]

  depends_on = [helm_release.alloy_gateway]
}
