resource "aws_dynamodb_table" "execution" {
  name         = "auto-repair-shop-execution-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
  attribute {
    name = "gsi1pk"
    type = "S"
  }
  attribute {
    name = "gsi1sk"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi1"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL"
  }
}

resource "aws_ssm_parameter" "table_name" {
  name  = "/auto-repair-shop/${var.environment}/execution/dynamodb/table-name"
  type  = "String"
  value = aws_dynamodb_table.execution.name
}
