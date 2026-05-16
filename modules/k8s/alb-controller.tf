# AWS Academy doesn't permit iam:CreatePolicy/AttachRolePolicy on LabRole.
# The controller inherits the node IAM (LabRole + VocLabPolicy*), which already
# covers EC2/ELB actions needed by the load balancer controller.

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = local.lab_role_arn
    }
  }
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"
  namespace  = "kube-system"

  set = [
    { name = "clusterName", value = var.cluster_name },
    { name = "serviceAccount.create", value = "false" },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
    { name = "region", value = var.aws_region },
    { name = "vpcId", value = var.vpc_id },
  ]

  depends_on = [kubernetes_service_account.alb_controller]
}
