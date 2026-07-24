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
