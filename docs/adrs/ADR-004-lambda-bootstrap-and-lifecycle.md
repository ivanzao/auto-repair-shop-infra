# ADR-004 — Lambda Bootstrap, ECR Pull Through Cache e lifecycle.ignore_changes

**Status:** Accepted
**Data:** 2026-05-26

## Contexto

Os Lambdas (`login`, `authorizer`, `email`) são imagens de container no GHCR
(`ghcr.io/ivanzao/...`) acessadas via ECR Pull Through Cache (PTC). O Terraform
cria a infraestrutura base dos Lambdas, mas o lifecycle das imagens (push + deploy)
é propriedade do pipeline `lambdas` no CI/CD.

A inicialização de banco (criação de roles e databases) foi originalmente planejada
via provider `cyrilgdn/postgresql`, que exige acesso TCP direto ao RDS. Isso é
possível somente de dentro da VPC, criando dependência circular no bootstrap inicial.

## Decisões

### 1. Ordem de bootstrap dos Lambdas

```
1. terraform apply -target=module.registry
2. Pipeline lambdas: docker push → GHCR + docker pull → ECR PTC (aquece o cache)
3. terraform apply (completo)
```

O ECR PTC só mantém imagem em cache após o primeiro pull. Se o Terraform criar o
Lambda antes do cache estar aquecido, a criação falha com "image not found". O
pipeline faz `docker pull` contra a URL PTC logo após o push no GHCR.

### 2. lifecycle.ignore_changes nos Lambdas

```hcl
lifecycle {
  ignore_changes = [image_uri, environment]
}
```

Após o bootstrap, o pipeline usa `update-function-code` + `update-function-configuration`
diretamente via AWS CLI para deploys day-to-day. O Terraform não gerencia o runtime
lifecycle — apenas a infraestrutura base. `ignore_changes` evita que `terraform apply`
reverta para a URI de placeholder definida no código.

### 3. DB init via Kubernetes Job (não provider postgresql)

O provider `cyrilgdn/postgresql` exige conexão TCP direta ao RDS na porta 5432. No
bootstrap, antes do cluster EKS existir, não há executor VPC-local disponível.

Solução: `kubernetes_job_v1.db_init` em `modules/k8s/db-init.tf`. O Job roda
in-cluster após EKS e RDS estarem ativos, com SQL idempotente (`IF NOT EXISTS`).
O Terraform aguarda conclusão (`wait_for_completion = true`) antes de continuar.

O nome do Job inclui um hash das credenciais: rotações de senha criam um Job novo,
já que Jobs completados são imutáveis no Kubernetes.

## Consequências

- `modules/db` usa apenas o provider AWS (Secrets Manager). O provider `postgresql`
  foi removido de `modules/db/versions.tf` — o módulo não continha nenhum resource
  `postgresql_*`.
- Deploys normais de Lambda não precisam de `terraform apply`.
- `terraform apply` completo falha se o cache PTC não estiver aquecido.
