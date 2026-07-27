# 01. Component Overview

Visão de alto nível dos componentes do Auto Repair Shop na AWS.

```mermaid
flowchart LR
    classDef external fill:#f9f,stroke:#333,stroke-width:1px
    classDef aws fill:#ff9,stroke:#333,stroke-width:1px
    classDef app fill:#9cf,stroke:#333,stroke-width:1px
    classDef data fill:#9f9,stroke:#333,stroke-width:1px
    classDef obs fill:#fcf,stroke:#333,stroke-width:1px

    Browser([Atendente]):::external
    Customer([Cliente do email]):::external
    MailerSend([MailerSend SMTP]):::external

    subgraph APIGW["AWS API Gateway HTTP API"]
        Route_login["POST /auth/login"]
        Route_v1["ANY /v1/{proxy+}"]
        Route_quote["GET /v1/orders/quote/*"]
    end
    APIGW:::aws

    subgraph Lambdas
        L_authorizer["Lambda authorizer<br/>(JWT validate)"]
        L_login["Lambda login<br/>(CPF + senha → JWT)"]
        L_email["Lambda email<br/>(SQS consumer)"]
    end
    L_authorizer:::aws
    L_login:::aws
    L_email:::aws

    subgraph EKS["EKS Cluster"]
        App["Auto Repair Shop<br/>Ktor + Exposed"]:::app
        OTel["OTel Operator<br/>(Java agent inject)"]:::obs
        Alloy["Alloy daemonset<br/>(logs/traces collector)"]:::obs
    end

    subgraph DataPlane
        RDS[("RDS PostgreSQL 16<br/>attendants · customers<br/>orders · events")]:::data
        SNS["SNS topic<br/>events"]:::aws
        SQS["SQS queue<br/>email + DLQ"]:::aws
        Secrets["Secrets Manager<br/>(DB creds, JWT HMAC)"]:::aws
        SSM["SSM Parameter Store<br/>(service registry)"]:::aws
    end

    subgraph Observability["Observability stack (LGTM)"]
        Prom["Prometheus + Alertmanager"]:::obs
        Grafana["Grafana<br/>(APM, business, errors dashboards)"]:::obs
        Loki["Loki (logs)"]:::obs
        Tempo["Tempo (traces)"]:::obs
        BlackBox["Blackbox exporter<br/>(uptime)"]:::obs
    end

    Browser -->|"Bearer JWT"| Route_v1
    Customer -->|"link público"| Route_quote
    Browser -->|"CPF + senha"| Route_login

    Route_v1 -->|invoke| L_authorizer
    L_authorizer -.->|"X-User-Id<br/>X-User-Role"| Route_v1
    Route_login --> L_login
    Route_v1 -->|"VPC Link → NLB"| App
    Route_quote -->|"VPC Link → NLB"| App

    L_login -->|"verifica status<br/>+ bcrypt"| RDS
    App -->|JDBC| RDS
    App -->|publish event| SNS
    SNS --> SQS
    SQS --> L_email
    L_email -->|"HTTPS via NAT"| MailerSend

    App --> OTel
    OTel -->|"OTLP"| Alloy
    Alloy --> Loki
    Alloy --> Tempo
    Prom -.->|"scrape /metrics"| App
    Grafana --> Prom
    Grafana --> Loki
    Grafana --> Tempo
    BlackBox -.-> APIGW

    App -.->|"get JDBC creds"| Secrets
    L_login -.-> Secrets
    L_email -.-> Secrets
    App -.->|"resolve SNS ARN, etc"| SSM
```

## Componentes principais

| Componente | Responsabilidade |
|---|---|
| **API Gateway HTTP API** | Entrada única. Roteia para Lambdas (auth) e VPC Link → NLB → app |
| **Lambda authorizer** | Valida JWT a cada request `/v1/*` protegido, injeta headers `X-User-Id` e `X-User-Role` |
| **Lambda login** | Recebe `POST /auth/login`, valida CPF + bcrypt, consulta `users.status='ACTIVE'`, emite JWT |
| **Lambda email** | Consumidor SQS; renderiza template e envia via MailerSend |
| **App (EKS)** | Domínio: ordens de serviço, clientes, veículos, atendentes, serviços, suprimentos |
| **RDS PostgreSQL 16** | Único banco; databases lógicos por env; user `app_*` + user `grafana_*` |
| **SNS → SQS** | Outbox pattern: app publica `external=true` events, SQS distribui pra Lambda email |
| **LGTM stack** | Prometheus (metrics), Loki (logs), Tempo (traces), Grafana (UI), Alertmanager (alertas) |

## Fluxos atravessando a borda

1. **Atendente autentica** → `POST /auth/login` → JWT
2. **Atendente acessa rota protegida** → `Authorization: Bearer <jwt>` → authorizer valida → app processa
3. **Cliente aprova orçamento** → link do email → `GET /v1/orders/quote/approve?token=...` (público, sem authorizer)
4. **App emite email** → grava em `events` (outbox) → scheduler publica em SNS → SQS → Lambda email → MailerSend
