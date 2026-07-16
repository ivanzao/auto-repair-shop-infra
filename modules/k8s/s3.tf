locals {
  bucket_prefix = var.s3_bucket_prefix != "" ? var.s3_bucket_prefix : "auto-repair-shop-${var.environment}"

  # Retention by env and signal — tighter in hml.
  loki_retention_days  = var.environment == "prod" ? 30 : 7
  tempo_retention_days = var.environment == "prod" ? 14 : 3
}

resource "aws_s3_bucket" "loki" {
  bucket        = "${local.bucket_prefix}-loki-${var.caller_account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = local.loki_retention_days
    }
  }
}

resource "aws_s3_bucket" "tempo" {
  bucket        = "${local.bucket_prefix}-tempo-${var.caller_account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id

  rule {
    id     = "expire-traces"
    status = "Enabled"

    filter {}

    expiration {
      days = local.tempo_retention_days
    }
  }
}

