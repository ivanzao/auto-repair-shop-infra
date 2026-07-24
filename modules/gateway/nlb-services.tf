locals {
  # NodePorts são convenção interna (contrato com os manifests dos apps), não
  # config de ambiente — por isso vivem aqui como literais, não como variáveis.
  node_ports = {
    order     = 30080
    billing   = 30081
    execution = 30082
  }

  services = {
    order = {
      tg_name       = local.app_target_group_name
      node_port     = local.node_ports.order
      listener_port = 80
    }
    billing = {
      tg_name       = "auto-repair-shop-billing-${var.environment}"
      node_port     = local.node_ports.billing
      listener_port = 8081
    }
    execution = {
      tg_name       = "auto-repair-shop-execution-${var.environment}"
      node_port     = local.node_ports.execution
      listener_port = 8082
    }
  }

  service_asg_attachments = {
    for pair in setproduct(keys(local.services), var.node_group_asg_names) :
    "${pair[0]}-${pair[1]}" => { service = pair[0], asg = pair[1] }
  }
}

resource "aws_lb_target_group" "service" {
  for_each = local.services

  name                 = each.value.tg_name
  port                 = each.value.node_port
  protocol             = "TCP"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 30
  preserve_client_ip   = "false"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/health"
    unhealthy_threshold = 3
  }

  tags = { Name = each.value.tg_name }
}

resource "aws_autoscaling_attachment" "service" {
  for_each = local.service_asg_attachments

  autoscaling_group_name = each.value.asg
  lb_target_group_arn    = aws_lb_target_group.service[each.value.service].arn
}

resource "aws_lb_listener" "service" {
  for_each = local.services

  load_balancer_arn = aws_lb.app.arn
  port              = each.value.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }
}

resource "aws_security_group_rule" "vpc_link_to_service_listener" {
  for_each = local.services

  type                     = "ingress"
  security_group_id        = aws_security_group.app_nlb.id
  source_security_group_id = var.lambda_sg_id
  from_port                = each.value.listener_port
  to_port                  = each.value.listener_port
  protocol                 = "tcp"
  description              = "Allow API Gateway VPC Link to reach the ${each.key} NLB listener"
}

resource "aws_security_group_rule" "service_nlb_to_eks" {
  for_each = local.services

  type                     = "egress"
  security_group_id        = aws_security_group.app_nlb.id
  source_security_group_id = var.eks_cluster_sg_id
  from_port                = each.value.node_port
  to_port                  = each.value.node_port
  protocol                 = "tcp"
  description              = "Allow private app NLB to forward traffic to EKS nodes on the ${each.key} NodePort"
}

resource "aws_security_group_rule" "eks_from_service_nlb" {
  for_each = local.services

  type                     = "ingress"
  security_group_id        = var.eks_cluster_sg_id
  source_security_group_id = aws_security_group.app_nlb.id
  from_port                = each.value.node_port
  to_port                  = each.value.node_port
  protocol                 = "tcp"
  description              = "Allow EKS nodes to receive ${each.key} NodePort traffic from private app NLB"
}
