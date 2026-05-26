module "vpc" {
  source       = "../modules/vpc"
  name         = "auto-repair-shop-hml"
  environment  = "hml"
  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "auto-repair-shop-hml-cluster"
}

module "eks" {
  source             = "../modules/eks"
  environment        = "hml"
  cluster_name       = "auto-repair-shop-hml-cluster"
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "rds" {
  source               = "../modules/rds"
  environment          = "hml"
  db_identifier        = "auto-repair-shop-hml-db"
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine_version    = var.db_engine_version
  db_master_username   = var.db_master_username
  db_master_password   = var.db_master_password
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_cluster_sg_id    = module.eks.cluster_sg_id
  lambda_sg_id         = module.vpc.lambda_sg_id

  skip_final_snapshot         = true
  secret_recovery_window_days = 0
}

module "db" {
  source          = "../modules/db"
  environment     = "hml"
  rds_endpoint    = module.rds.rds_endpoint
  rds_port        = module.rds.rds_port
  db_app_password = var.db_app_password

  secret_recovery_window_days = 0

  depends_on = [module.rds]
}

resource "kubernetes_manifest" "otel_instrumentation" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "Instrumentation"
    metadata = {
      name      = "auto-repair-shop"
      namespace = "auto-repair-shop-hml"
    }
    spec = {
      exporter = {
        endpoint = "http://alloy-daemonset.observability.svc.cluster.local:4318"
      }
      propagators = ["tracecontext", "baggage"]
      sampler = {
        type     = "parentbased_traceidratio"
        argument = "1"
      }
      resource = {
        resourceAttributes = {
          "service.name" = "auto-repair-shop"
          "environment"  = "hml"
        }
      }
      java = {
        env = [
          { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
          { name = "OTEL_LOGS_EXPORTER", value = "none" },
        ]
      }
    }
  }

  depends_on = [module.k8s]
}

module "k8s" {
  source                 = "../modules/k8s"
  environment            = "hml"
  cluster_name           = module.eks.cluster_name
  aws_region             = var.aws_region
  vpc_id                 = module.vpc.vpc_id
  caller_account_id      = data.aws_caller_identity.current.account_id
  rds_endpoint           = module.rds.rds_endpoint
  rds_port               = module.rds.rds_port
  db_master_password     = var.db_master_password
  db_app_password        = var.db_app_password
  grafana_db_password    = var.grafana_db_password
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.eks, module.rds]
}

module "registry" {
  source        = "../modules/registry"
  environment   = "hml"
  ghcr_username = var.ghcr_username
  ghcr_token    = var.ghcr_token
}

module "gateway" {
  source                = "../modules/gateway"
  environment           = "hml"
  aws_region            = var.aws_region
  private_subnet_ids    = module.vpc.private_subnet_ids
  lambda_sg_id          = module.vpc.lambda_sg_id
  eks_cluster_sg_id     = module.eks.cluster_sg_id
  vpc_id                = module.vpc.vpc_id
  node_group_asg_names  = module.eks.node_group_asg_names
  ecr_repository_prefix = module.registry.ecr_repository_prefix
  db_secret_arn         = module.db.secret_arn_app

  depends_on = [module.k8s, module.registry]
}

module "messaging" {
  source                = "../modules/messaging"
  environment           = "hml"
  aws_region            = var.aws_region
  private_subnet_ids    = module.vpc.private_subnet_ids
  lambda_sg_id          = module.vpc.lambda_sg_id
  ecr_repository_prefix = module.registry.ecr_repository_prefix

  depends_on = [module.registry]
}
