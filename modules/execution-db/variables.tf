variable "environment" {
  description = "Environment name (e.g. prod, hml)"
  type        = string
}

variable "services" {
  description = "Nomes dos serviços que possuem tabela DynamoDB (schema padrão single-table)"
  type        = set(string)
}
