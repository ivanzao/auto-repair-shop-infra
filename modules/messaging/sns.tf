resource "aws_sns_topic" "events" {
  name = "auto-repair-shop-events-${var.environment}"
}
