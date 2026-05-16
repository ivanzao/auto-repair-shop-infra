# auto-repair-shop-infra

Terraform monorepo da infraestrutura do Auto Repair Shop, com **um root por ambiente** (`hml/`, `prod/`) consumindo módulos compartilhados em `modules/`.

## Estrutura

```
hml/        # root terraform do ambiente HML  (state key: hml/terraform.tfstate)
prod/       # root terraform do ambiente PROD (state key: prod/terraform.tfstate)
modules/
  vpc/      # VPC, subnets (2 pub + 2 priv), IGW, NAT, lambda SG
  eks/      # EKS cluster (1.32), launch template (IMDS hop_limit=2), node group
  rds/      # RDS PostgreSQL 16 + db-master secret + parameter/subnet/security groups
  db/       # Secret do usuário app (criação real de roles/DBs feita por Job in-cluster)
  k8s/      # Namespaces, SA, ALB controller, observability (Helm), DB init Job, S3 buckets de loki/tempo
```

Cada ambiente é um state separado no bucket `auto-repair-shop-tfstate-<account>`. HML e PROD são **clusters EKS independentes** com VPCs distintas (10.0.0.0/16 vs 10.1.0.0/16).

## Por que um root por ambiente em vez de sub-projeto por camada

- O lab AWS Academy tem só `LabRole` — não dá pra criar OIDC providers nem policies próprias, então a separação por camada não traz isolamento real de IAM.
- Manter `hml` e `prod` em roots separados preserva blast radius: um `destroy` em `prod/` não toca `hml/`.
- Os modules em `modules/` são versionados juntos com os envs — mudança propaga pra ambos via PR + deploy sequencial.

## CI/CD

- **pr-check.yaml** — `terraform fmt/validate/plan` por ambiente; resultado vira comentário no PR.
- **deploy.yaml** — em `push` para `main`:
  1. `deploy-hml` — `terraform init` + apply duas vezes em `hml/`
  2. `deploy-prod` — só executa se HML deu sucesso; mesmo fluxo em `prod/`

O **two-pass apply** é necessário porque o provider `kubernetes_manifest` precisa falar com a API do cluster no plan time. Pass 1 builda VPC+EKS+RDS+`module.k8s` (helm releases inclusos); pass 2 aplica manifests standalone como `otel_instrumentation` que dependem de CRDs do pass 1.

## Setup inicial (bootstrap do state bucket)

O workflow `deploy.yaml` já cria o bucket no primeiro run se ele não existir (`aws s3api head-bucket || create + enable versioning + encryption`). Não há script separado.

## Outputs SSM (consumidos por aplicações)

Publicados em `hml/ssm.tf` e `prod/ssm.tf`:

| Param | Conteúdo |
|-------|----------|
| `/auto-repair-shop/{hml,prod}/eks/cluster-name` | Nome do cluster EKS (pra `aws eks update-kubeconfig` no CI das apps) |
| `/auto-repair-shop/{hml,prod}/db/secret-arn` | ARN do Secrets Manager — JSON com `host`, `port`, `dbname`, `username`, `password` do app DB |

Apps que precisarem das credenciais do DB devem ler o ARN no SSM e fazer `aws secretsmanager get-secret-value` pra extrair o JSON. **Não publicamos host/dbname/username separadamente em SSM** — tudo vive no JSON do Secrets Manager pra evitar drift.

**Outros params SSM consumidos pelas apps**:

| Param | Publicado por |
|-------|---------------|
| `/auto-repair-shop/{env}/sns/events-topic-arn` | `modules/messaging` |
| `/auto-repair-shop/{env}/sqs/email-queue-arn`  | `modules/messaging` |
| `/auto-repair-shop/{env}/apigw/endpoint`       | `modules/gateway`   |
| `/auto-repair-shop/{env}/apigw/api-id`         | `modules/gateway`   |
| `/auto-repair-shop/{env}/apigw/vpc-link-id`    | `modules/gateway`   |
| `/auto-repair-shop/{env}/apigw/execution-arn`  | `modules/gateway`   |
| `/auto-repair-shop/{env}/apigw/private-listener-arn` | `modules/gateway` |
| `/auto-repair-shop/{env}/alb/app-target-group-arn`   | `modules/gateway` (consumido pelo `TargetGroupBinding` do app — CRD `elbv2.k8s.aws/v1beta1` exige ARN, não name) |

O deploy da app **assume que esses params existem** — sem eles o pipeline falha.

## ADRs

Decisões importantes estão em `docs/adrs/`:

- **ADR-001** — restrições de storage do AWS Academy
- **ADR-002** — senhas hardcoded para Grafana/admin em contexto acadêmico
- **ADR-003** — acesso a S3 dos pods via IMDS hop_limit=2 (substitui IRSA, que é bloqueado no Academy)
