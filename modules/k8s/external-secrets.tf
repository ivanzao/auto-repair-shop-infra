locals {
  eso_cluster_secret_store = "aws-secrets-manager"
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.7.0"
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 300

  depends_on = [helm_release.alb_controller]
}

# ClusterSecretStore aplicado via chart local: kubernetes_manifest falha no plan
# quando o CRD ainda não existe no cluster; o helm só valida no apply.
resource "helm_release" "eso_resources" {
  name      = "eso-resources"
  chart     = "${path.module}/charts/eso-resources"
  namespace = "external-secrets"
  timeout   = 120

  values = [
    yamlencode({
      storeName    = local.eso_cluster_secret_store
      region       = var.aws_region
      appNamespace = local.app_namespace
    })
  ]

  depends_on = [helm_release.external_secrets]
}

resource "aws_ssm_parameter" "eso_cluster_secret_store" {
  name        = "/auto-repair-shop/${var.environment}/eso/cluster-secret-store-name"
  type        = "String"
  value       = local.eso_cluster_secret_store
  description = "Nome do ClusterSecretStore que os ExternalSecrets dos apps devem referenciar"
}
