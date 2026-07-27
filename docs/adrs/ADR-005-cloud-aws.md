# ADR-005 — Escolha de cloud AWS

**Status:** Aceito em 2026-05-25

## Contexto

A plataforma exige API Gateway, função serverless, banco gerenciado e Kubernetes. A escolha de cloud impacta ferramentas IaC, ecossistema de observabilidade, custo, vendor lock-in e tempo de bootstrap.

Restrição adicional do ambiente acadêmico: **AWS Academy** disponível com `LabRole` único, créditos fixos, sem permissão para criar IAM custom, OIDC providers ou roles próprias.

## Opções consideradas

### Opção A: AWS (escolhida)

**Prós**:
- Disponível com créditos via AWS Academy (custo zero para o projeto)
- API Gateway HTTP API v2 maduro, com suporte nativo a Lambda Authorizer e VPC Link v2 (integração com NLB)
- EKS gerenciado, RDS PostgreSQL gerenciado, Lambda com container image
- Ecossistema Terraform robusto (`hashicorp/aws`)
- Documentação extensa do agente Java do OpenTelemetry para EKS

**Contras**:
- Vendor lock-in em alguns serviços (API Gateway, Lambda), mitigado por adotar 12-factor app e domínio limpo
- AWS Academy limita criação de IAM roles (somente `LabRole`), o que afeta IRSA e afins

### Opção B: GCP (GKE + Cloud Run + Cloud SQL)

**Prós**: Cloud Run mais simples que Lambda + ECR pull-through.
**Contras**: sem créditos acadêmicos garantidos no programa, menos familiaridade com Terraform GCP.
**Rejeitado**: sem acesso garantido a créditos.

### Opção C: Azure (AKS + Functions + Azure Database)

**Prós**: Azure for Students disponível.
**Contras**: API Management mais caro que API Gateway HTTP, integração com observabilidade open-source (stack LGTM) menos polida que na AWS.
**Rejeitado**: documentação Terraform menos rica para a stack escolhida.

## Recomendação

**Adotar AWS.**

A combinação API Gateway HTTP + Lambda + EKS + RDS é nativa e bem documentada. O AWS Academy resolve o problema de custo. As limitações de IAM são contornáveis; ver [ADR-002](ADR-002-aws-academy-iam-constraints.md) e [ADR-003](ADR-003-lambda-authorizer-header-injection.md).

## Consequências

**Positivas**:
- Custo zero durante o projeto
- Stack alinhada com a maioria das vagas de mercado no Brasil
- Terraform `hashicorp/aws` com cobertura completa

**Negativas**:
- Lock-in em API Gateway HTTP (formato de payload v2 específico)
- Lambdas usam runtime AWS-específico (`provided.al2023-arm64`)

**Mitigações**:
- Os microsserviços rodam em Kubernetes, portáveis para qualquer cloud
- Lambdas em Go puro: trocar de runtime exige reescrever apenas o `main.go` (assinatura do handler)
