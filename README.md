# auto-repair-shop-infra

Terraform da infraestrutura completa do Auto Repair Shop na AWS — dois ambientes independentes (`hml` e `prod`), cada um com VPC, EKS, RDS e stack de observabilidade provisionados a partir de módulos compartilhados.

---

## Estrutura de Pastas

```
hml/          # Root Terraform do ambiente HML
prod/         # Root Terraform do ambiente PROD
modules/
  vpc/        # VPC, subnets, IGW, NAT Gateway
  eks/        # Cluster EKS 1.32 + nodegroup t3.medium
  rds/          # RDS PostgreSQL 16 + Secrets Manager (genérico: order e billing)
  execution-db/ # Tabela DynamoDB do execution service
  k8s/          # Namespaces, ALB Controller, observabilidade (Helm), init do banco
  gateway/      # API Gateway HTTP API, Lambda Authorizer, VPC Link, NLB
  messaging/    # SNS, SQS, Lambda email
  registry/     # ECR Pull Through Cache para GHCR
docs/adrs/       # Architecture Decision Records
docs/diagrams/   # Diagrama de componentes da plataforma
scripts/         # Tunnels para Grafana e RDS
```

> **Nota sobre 3 repositórios:** o enunciado sugere repos separados para K8s Infra e BD Infra. Mantemos os dois consolidados aqui por limitação do AWS Academy — sem criação de roles IAM por sub-projeto, a separação não traz isolamento real. A decisão está detalhada em [ADR-004](docs/adrs/ADR-004-infra-monorepo.md).

---

## Arquitetura

Cada ambiente é um state Terraform independente no S3. HML e PROD têm VPCs distintas (10.0.0.0/16 vs 10.1.0.0/16) e clusters EKS separados.

```
Internet
    │
    ▼
AWS API Gateway HTTP API
    ├── POST /auth/login ──────────────► Lambda login (CPF + bcrypt → JWT)
    └── ANY /v1/{proxy+} ──► Lambda authorizer ──► VPC Link ──► NLB ──► EKS
                                                                         │
                                                                       App pod
                                                                         │
                                                                    RDS PostgreSQL
                                                                         │
                                                               SNS ──► SQS ──► Lambda email
```

O app não conhece o segredo JWT — o Lambda Authorizer valida o token e injeta `X-User-Id` e `X-User-Role` como headers antes de encaminhar para os pods.

### Observabilidade

Stack LGTM completo no namespace `observability`:

- **Prometheus** (via kube-prometheus-stack) — métricas do cluster e da app
- **Grafana** — dashboards pré-carregados no bootstrap (APM, ordens de serviço, erros)
- **Loki** — logs estruturados JSON coletados pelo Alloy daemonset
- **Tempo** — traces distribuídos injetados automaticamente pelo OTel Operator
- **Alertmanager** — alertas de latência, CrashLoop, erros de processamento e uptime

---

## Stack

| Componente | Tecnologia |
|---|---|
| IaC | Terraform 1.10 |
| Compute | EKS 1.32 (nós t3.medium) |
| Banco | RDS PostgreSQL 16 (db.t3.micro) |
| API Gateway | AWS API Gateway HTTP API v2 |
| Serverless | AWS Lambda (container, arm64) |
| Messaging | SNS + SQS |
| Observabilidade | Prometheus, Grafana, Loki, Tempo, Alloy |
| Manifests K8s | Helm (via provider Terraform) |

---

## Acesso Local aos Serviços

O Grafana e o RDS ficam dentro da VPC. Os scripts abaixo abrem tunnels para acesso local:

```bash
# Grafana → http://localhost:3000  (admin / admin)
./scripts/grafana-tunnel.sh prod

# RDS → localhost:5432  (credenciais impressas na tela)
./scripts/rds-tunnel.sh prod
```

Substitua `prod` por `hml` para o ambiente de homologação.

**Pré-requisitos:** `aws cli`, `kubectl`, `jq` (só no tunnel de RDS).

---

## Deploy

O deploy é feito automaticamente pelo pipeline em `push` para `main`:

1. Deploy HML — `terraform apply` em `hml/`
2. Deploy PROD — executa somente se HML foi bem-sucedido

O primeiro deploy exige dois passes (targets específicos, depois apply completo) por conta de dependências entre CRDs e manifests Kubernetes. O pipeline cuida disso automaticamente.

---

## CI/CD Pipeline

| Workflow | Trigger | O que faz |
|---|---|---|
| `pr-check.yaml` | PRs para `main` | `terraform fmt`, `validate` e `plan` por ambiente; resultado como comentário no PR |
| `deploy.yaml` | Push `main` | Apply HML → Apply PROD (sequencial) |

### Secrets necessários no GitHub

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` | Credenciais AWS Academy |
| `DB_MASTER_PASSWORD` | Senha do usuário master do RDS |
| `DB_PASSWORD_HML` / `DB_PASSWORD_PROD` | Senhas da aplicação (order) por ambiente |
| `DB_BILLING_PASSWORD_HML` / `DB_BILLING_PASSWORD_PROD` | Senhas da aplicação do billing por ambiente |
| `GHCR_TOKEN` | PAT para pull de imagens do GHCR |

---

## Contrato de Integração (SSM Parameter Store)

Os outros repos consomem outputs da infra via SSM — sem `terraform_remote_state`.

| Parâmetro | Publicado por | Conteúdo |
|---|---|---|
| `/auto-repair-shop/{env}/eks/cluster-name` | `hml/`, `prod/` | Nome do cluster EKS |
| `/auto-repair-shop/{env}/order/db/secret-arn` | `hml/`, `prod/` | ARN do secret de credenciais do order (JSON com host, port, dbname, user, password) |
| `/auto-repair-shop/{env}/apigw/endpoint` | `modules/gateway` | URL pública do API Gateway |
| `/auto-repair-shop/{env}/sns/events-topic-arn` | `modules/messaging` | ARN do tópico SNS de eventos (legado, monólito) |
| `/auto-repair-shop/{env}/sns/{order\|billing\|execution}-events-topic-arn` | `modules/messaging` | ARN do tópico de eventos de cada serviço (saga Fase 4) |
| `/auto-repair-shop/{env}/sqs/{order\|billing\|execution}-queue-url` | `modules/messaging` | URL da fila (inbox) de cada serviço — assina os tópicos dos outros dois |
| `/auto-repair-shop/{env}/billing/db/secret-arn` | `hml/`, `prod/` | ARN do secret de credenciais do billing (JSON com host, port, dbname, user, password) |
| `/auto-repair-shop/{env}/billing/mercadopago-secret-arn` | `hml/`, `prod/` | ARN do secret do Mercado Pago — shell criado pela infra; valor populado pelo CI do repo do billing |
| `/auto-repair-shop/{env}/execution/dynamodb/table-name` | `modules/execution-db` | Nome da tabela DynamoDB do execution service |
| `/auto-repair-shop/{env}/alb/{billing\|execution}-target-group-arn` | `modules/gateway` | Target group NLB de cada serviço (NodePorts 30081/30082, listeners 8081/8082) |
| `/auto-repair-shop/{env}/{order\|billing\|execution}/node-port` | `modules/gateway` | NodePort que a `Service` de cada app deve expor (contrato com os manifests dos apps) |
| `/auto-repair-shop/{env}/eso/cluster-secret-store-name` | `modules/k8s` | Nome do ClusterSecretStore do External Secrets Operator que os `ExternalSecret` dos apps devem referenciar |

---

## ADRs

Decisões arquiteturais documentadas em `docs/adrs/`:

- **ADR-001** — Credenciais padrão no contexto acadêmico
- **ADR-002** — Contornando restrições de IAM do AWS Academy
- **ADR-003** — Lambda Authorizer injeta headers; app não revalida JWT
- **ADR-004** — K8s e BD no mesmo repositório de infra
