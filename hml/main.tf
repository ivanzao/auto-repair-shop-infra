module "vpc" {
  source       = "../modules/vpc"
  name         = "auto-repair-shop-${var.environment}"
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
}

module "eks" {
  source             = "../modules/eks"
  environment        = var.environment
  cluster_name       = local.cluster_name
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

locals {
  rds_instances = {
    order = {
      db_identifier      = "auto-repair-shop-${var.environment}-db"
      secret_name_prefix = "auto-repair-shop"
      app_db_name        = "auto_repair_shop_order_${var.environment}"
      app_db_username    = "order_${var.environment}"
      db_app_password    = var.db_order_app_password
    }
    billing = {
      db_identifier      = "auto-repair-shop-billing-${var.environment}-db"
      secret_name_prefix = "auto-repair-shop-billing"
      app_db_name        = "auto_repair_shop_billing_${var.environment}"
      app_db_username    = "app_billing_${var.environment}"
      db_app_password    = var.db_billing_app_password
    }
    user = {
      db_identifier      = "auto-repair-shop-user-${var.environment}-db"
      secret_name_prefix = "auto-repair-shop-user"
      app_db_name        = "auto_repair_shop_user_${var.environment}"
      app_db_username    = "app_user_${var.environment}"
      db_app_password    = var.db_user_app_password
    }
  }
}

module "rds" {
  source   = "../modules/rds"
  for_each = local.rds_instances

  environment          = var.environment
  db_identifier        = each.value.db_identifier
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine_version    = var.db_engine_version
  db_master_username   = var.db_master_username
  db_master_password   = var.db_master_password
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_cluster_sg_id    = module.eks.cluster_sg_id
  lambda_sg_id         = module.vpc.lambda_sg_id

  # skip_final_snapshot = true in BOTH envs because this is an academic lab —
  # destroys happen rotineiramente and the snapshot guardrail just adds friction.
  # See ADR-002 (production-hardening section) before promoting to a real prod.
  skip_final_snapshot         = true
  secret_recovery_window_days = 0
  secret_name_prefix          = each.value.secret_name_prefix
  db_app_password             = each.value.db_app_password
  app_db_name                 = each.value.app_db_name
  app_db_username             = each.value.app_db_username
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
  source                 = "../modules/k8s"
  environment            = var.environment
  cluster_name           = module.eks.cluster_name
  aws_region             = var.aws_region
  vpc_id                 = module.vpc.vpc_id
  caller_account_id      = data.aws_caller_identity.current.account_id
  rds_endpoint           = module.rds["order"].rds_endpoint
  rds_port               = module.rds["order"].rds_port
  db_master_password     = var.db_master_password
  db_order_app_password  = var.db_order_app_password
  grafana_db_password    = var.grafana_db_password
  grafana_admin_password = var.grafana_admin_password
  order_db_name          = module.rds["order"].db_name
  order_db_role          = module.rds["order"].db_role_name

  rds_billing_endpoint    = module.rds["billing"].rds_endpoint
  db_billing_app_password = var.db_billing_app_password
  billing_db_name         = module.rds["billing"].db_name
  billing_db_role         = module.rds["billing"].db_role_name

  rds_user_endpoint    = module.rds["user"].rds_endpoint
  db_user_app_password = var.db_user_app_password
  user_db_name         = module.rds["user"].db_name
  user_db_role         = module.rds["user"].db_role_name

  depends_on = [module.eks, module.rds]
}

module "execution_db" {
  source      = "../modules/execution-db"
  environment = var.environment
}

module "registry" {
  source        = "../modules/registry"
  environment   = var.environment
  aws_region    = var.aws_region
  ghcr_username = var.ghcr_username
  ghcr_token    = var.ghcr_token
}

module "gateway" {
  source                   = "../modules/gateway"
  environment              = var.environment
  private_subnet_ids       = module.vpc.private_subnet_ids
  lambda_sg_id             = module.vpc.lambda_sg_id
  eks_cluster_sg_id        = module.eks.cluster_sg_id
  vpc_id                   = module.vpc.vpc_id
  node_group_asg_names     = module.eks.node_group_asg_names
  lambda_placeholder_image = module.registry.lambda_placeholder_image
  db_secret_arn            = module.rds["order"].secret_arn_app

  depends_on = [module.k8s, module.registry]
}

module "messaging" {
  source                   = "../modules/messaging"
  environment              = var.environment
  private_subnet_ids       = module.vpc.private_subnet_ids
  lambda_sg_id             = module.vpc.lambda_sg_id
  lambda_placeholder_image = module.registry.lambda_placeholder_image

  depends_on = [module.registry]
}
