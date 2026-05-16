data "aws_caller_identity" "current" {}

locals {
  lab_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  common_tags = {
    Environment = var.environment
    Application = "auto-repair-shop"
    ManagedBy   = "terraform"
  }
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = local.lab_role_arn
  version  = "1.32"

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  tags = local.common_tags
}

# Custom launch template solely to raise IMDS hop limit to 2.
# Pods need this to reach 169.254.169.254 and inherit LabRole creds.
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = local.lab_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  labels = { role = "general" }

  tags = local.common_tags

  depends_on = [aws_eks_cluster.main]
}
