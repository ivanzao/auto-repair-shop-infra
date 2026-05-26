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

## SSM Parameter Store — Contrato de Integração

As aplicações consomem outputs da infra via SSM Parameter Store, não via
`terraform_remote_state`. Isso desacopla o ciclo de deploy das aplicações
do estado do Terraform.

**Padrão de nomes:** `/auto-repair-shop/<env>/<recurso>/<atributo>`

| Parâmetro | Publicado por | Conteúdo |
|-----------|--------------|----------|
| `/auto-repair-shop/{env}/eks/cluster-name` | `hml/ssm.tf`, `prod/ssm.tf` | Nome do cluster EKS |
| `/auto-repair-shop/{env}/db/secret-arn` | `hml/ssm.tf`, `prod/ssm.tf` | ARN do secret de credenciais da app (JSON com host, port, dbname, username, password) |
| `/auto-repair-shop/{env}/apigw/endpoint` | `modules/gateway` | URL pública do API Gateway |
| `/auto-repair-shop/{env}/apigw/api-id` | `modules/gateway` | ID do HTTP API |
| `/auto-repair-shop/{env}/apigw/vpc-link-id` | `modules/gateway` | ID do VPC Link |
| `/auto-repair-shop/{env}/apigw/execution-arn` | `modules/gateway` | Execution ARN (para Lambda permissions) |
| `/auto-repair-shop/{env}/apigw/private-listener-arn` | `modules/gateway` | ARN do listener do NLB interno |
| `/auto-repair-shop/{env}/alb/app-target-group-arn` | `modules/gateway` | ARN do Target Group da app (CRD TargetGroupBinding exige ARN) |
| `/auto-repair-shop/{env}/sns/events-topic-arn` | `modules/messaging` | ARN do tópico SNS de eventos |
| `/auto-repair-shop/{env}/sqs/email-queue-arn` | `modules/messaging` | ARN da fila SQS de emails |

**Não publicamos** host/dbname/username separadamente em SSM — tudo vive no JSON do Secrets Manager para evitar drift. O deploy da app assume que esses parâmetros existem — sem eles o pipeline falha.

## Grafana Dashboards

Os dashboards são pré-carregados no bootstrap via ConfigMaps, não configurados manualmente.
O sidecar do Grafana (kube-prometheus-stack) monitora ConfigMaps com a label
`grafana_dashboard=1` em todos os namespaces e importa cada chave `*.json` como
um dashboard. A annotation `grafana_folder` agrupa dashboards em pastas na UI.

Isso garante que o Grafana inicia com dashboards prontas no primeiro deploy,
sem intervenção manual pós-bootstrap.

## Acesso local aos serviços do cluster

Os scripts em `scripts/` automatizam port-forward para serviços internos ao cluster. Aceitam `prod` ou `hml` como argumento (padrão: `prod`) e resolvem credenciais AWS pela cadeia padrão do CLI.

| Script | O que faz |
|---|---|
| `scripts/grafana-tunnel.sh [prod\|hml]` | Port-forward do Grafana → `http://localhost:3000` (admin / admin) |
| `scripts/rds-tunnel.sh [prod\|hml]` | Tunnel RDS via pod socat → `localhost:5432` (credenciais impressas na tela) |

```bash
./scripts/grafana-tunnel.sh prod   # abre http://localhost:3000
./scripts/rds-tunnel.sh prod       # abre localhost:5432
```

**Pré-requisitos:** `aws cli`, `kubectl`, `jq` (só `rds-tunnel.sh`).

O Grafana fica como `ClusterIP` por design — expô-lo como LoadBalancer o deixaria público sem autenticação de rede.

## ADRs

Decisões importantes estão em `docs/adrs/`:

- **ADR-001** — restrições de storage do AWS Academy
- **ADR-002** — senhas hardcoded para Grafana/admin em contexto acadêmico
- **ADR-003** — acesso a S3 dos pods via IMDS hop_limit=2 (substitui IRSA, que é bloqueado no Academy)
