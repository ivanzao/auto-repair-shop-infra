resource "aws_lb" "app" {
  name               = local.nlb_name
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.app_nlb.id]
  subnets            = var.private_subnet_ids

  tags = {
    Name = local.nlb_name
  }
}
