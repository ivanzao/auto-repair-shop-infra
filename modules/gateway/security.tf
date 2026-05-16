resource "aws_security_group" "app_nlb" {
  name        = "${local.app_target_group_name}-nlb-sg"
  description = "Security group for private app NLB"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.app_target_group_name}-nlb-sg"
  })
}

resource "aws_security_group_rule" "vpc_link_to_app_nlb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app_nlb.id
  source_security_group_id = var.lambda_sg_id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  description              = "Allow API Gateway VPC Link to reach private app NLB"
}

resource "aws_security_group_rule" "app_nlb_to_eks" {
  type                     = "egress"
  security_group_id        = aws_security_group.app_nlb.id
  source_security_group_id = var.eks_cluster_sg_id
  from_port                = var.app_node_port
  to_port                  = var.app_node_port
  protocol                 = "tcp"
  description              = "Allow private app NLB to forward traffic to EKS nodes on the app NodePort"
}

resource "aws_security_group_rule" "eks_from_app_nlb" {
  type                     = "ingress"
  security_group_id        = var.eks_cluster_sg_id
  source_security_group_id = aws_security_group.app_nlb.id
  from_port                = var.app_node_port
  to_port                  = var.app_node_port
  protocol                 = "tcp"
  description              = "Allow EKS nodes to receive app NodePort traffic from private app NLB"
}
