resource "aws_lb" "app" {
  name               = local.app_target_group_name
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.app_nlb.id]
  subnets            = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = local.app_target_group_name
  })
}

resource "aws_lb_target_group" "app" {
  name                 = local.app_target_group_name
  port                 = var.app_node_port
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
    protocol            = "TCP"
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, {
    Name = local.app_target_group_name
  })
}

resource "aws_autoscaling_attachment" "app" {
  count                  = length(var.node_group_asg_names)
  autoscaling_group_name = var.node_group_asg_names[count.index]
  lb_target_group_arn    = aws_lb_target_group.app.arn
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
