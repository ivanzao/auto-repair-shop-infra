provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# kubernetes and helm providers use exec to fetch the token at apply time,
# so they don't fail on the first apply before the cluster exists.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "auto-repair-shop-hml-cluster", "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "auto-repair-shop-hml-cluster", "--region", var.aws_region]
    }
  }
}

