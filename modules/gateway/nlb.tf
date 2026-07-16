resource "aws_lb" "app" {
  name               = local.app_target_group_name
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.app_nlb.id]
  subnets            = var.private_subnet_ids

  tags = {
    Name = local.app_target_group_name
  }
}

resource "aws_lb_target_group" "order" {
  name                 = local.app_target_group_name
  port                 = local.node_ports.order
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

  tags = {
    Name = local.app_target_group_name
  }
}

resource "aws_autoscaling_attachment" "order" {
  for_each = toset(var.node_group_asg_names)

  autoscaling_group_name = each.key
  lb_target_group_arn    = aws_lb_target_group.order.arn
}

resource "aws_lb_listener" "order" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order.arn
  }
}
