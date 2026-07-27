# ADR-002 — Contornando restrições de IAM do AWS Academy

**Status:** Aceito em 2026-05-26

## Contexto

O AWS Academy nega `iam:CreatePolicy`, `iam:AttachRolePolicy` e `iam:CreateRole` para o usuário de lab. Isso impede IRSA, o padrão de associar roles IAM dedicadas a ServiceAccounts por workload. Sem ele, o ALB Controller, os pods da app (SNS publish) e outros componentes não conseguiriam credenciais AWS.

## Decisão

Todos os workloads que precisam de credenciais AWS herdam a `LabRole` via IMDS com `http_put_response_hop_limit = 2` no launch template dos nós EKS. Sem anotações de ServiceAccount, sem roles dedicadas por workload.

## Consequências

- Sem isolamento de identidade entre workloads, aceitável num cluster single-tenant de lab
- Em produção real: criar roles IAM dedicadas com least-privilege por workload e usar IRSA ou EKS Pod Identity
