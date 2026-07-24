data "aws_caller_identity" "current" {}

module "vpc" {
  source       = "./vpc"
  name         = "auto-repair-shop-${var.environment}"
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
}

module "eks" {
  source             = "./eks"
  environment        = var.environment
  cluster_name       = local.cluster_name
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "rds" {
  source   = "./rds"
  for_each = local.db_app_passwords

  environment          = var.environment
  db_identifier        = "auto-repair-shop-${each.key}-${var.environment}-db"
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
  secret_name_prefix          = "auto-repair-shop-${each.key}"
  db_app_password             = each.value
  app_db_name                 = "auto_repair_shop_${each.key}_${var.environment}"
  app_db_username             = "app_${each.key}_${var.environment}"
}

resource "kubernetes_manifest" "otel_instrumentation" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "Instrumentation"
    metadata = {
      name      = "auto-repair-shop"
      namespace = "auto-repair-shop-${var.environment}"
    }
    spec = {
      exporter = {
        endpoint = "http://alloy-gateway.observability.svc.cluster.local:4318"
      }
      propagators = ["tracecontext", "baggage"]
      sampler = {
        type     = "parentbased_traceidratio"
        argument = "1"
      }
      resource = {
        resourceAttributes = {
          "service.name" = "auto-repair-shop"
          "environment"  = var.environment
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
  source            = "./k8s"
  environment       = var.environment
  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  caller_account_id = data.aws_caller_identity.current.account_id

  db_master_password     = var.db_master_password
  grafana_admin_password = var.grafana_admin_password

  app_databases = {
    for name, m in module.rds : name => {
      endpoint = m.rds_endpoint
      role     = m.db_role_name
      db       = m.db_name
    }
  }
  app_db_passwords = local.db_app_passwords

  depends_on = [module.eks, module.rds]
}

module "execution_db" {
  source      = "./execution-db"
  environment = var.environment
}

module "registry" {
  source        = "./registry"
  environment   = var.environment
  aws_region    = var.aws_region
  ghcr_username = var.ghcr_username
  ghcr_token    = var.ghcr_token
}

module "gateway" {
  source                   = "./gateway"
  environment              = var.environment
  private_subnet_ids       = module.vpc.private_subnet_ids
  lambda_sg_id             = module.vpc.lambda_sg_id
  eks_cluster_sg_id        = module.eks.cluster_sg_id
  vpc_id                   = module.vpc.vpc_id
  node_group_asg_names     = module.eks.node_group_asg_names
  lambda_placeholder_image = module.registry.lambda_placeholder_image
  db_secret_arn            = module.rds["user"].secret_arn_app

  depends_on = [module.k8s, module.registry]
}

module "messaging" {
  source                   = "./messaging"
  environment              = var.environment
  private_subnet_ids       = module.vpc.private_subnet_ids
  lambda_sg_id             = module.vpc.lambda_sg_id
  lambda_placeholder_image = module.registry.lambda_placeholder_image

  depends_on = [module.registry]
}
