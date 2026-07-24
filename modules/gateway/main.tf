data "aws_caller_identity" "current" {}

locals {
  app_target_group_name = "auto-repair-shop-${var.environment}-app"
  lab_role_arn          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}
