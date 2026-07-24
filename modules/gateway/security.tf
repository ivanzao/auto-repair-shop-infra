resource "aws_security_group" "app_nlb" {
  name        = "${local.app_target_group_name}-nlb-sg"
  description = "Security group for private app NLB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.app_target_group_name}-nlb-sg"
  }
}
