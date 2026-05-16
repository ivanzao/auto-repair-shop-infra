output "arc_runner_set_name" {
  description = "ARC runner scale set name — use as runs-on label in GitHub Actions"
  value       = "eks-${var.environment}"
}

output "app_namespace" {
  description = "Kubernetes namespace for the application"
  value       = kubernetes_namespace.app.metadata[0].name
}
