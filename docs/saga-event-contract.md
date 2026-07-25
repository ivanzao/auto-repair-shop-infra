# Contrato de Eventos da Saga (Fase 4)

Fonte única de verdade para a comunicação assíncrona entre os serviços **order**, **billing** e **execution**. Os três repos consomem este documento; qualquer mudança de payload, nome de evento ou topologia começa aqui.

Contexto de design: `docs/superpowers/specs/2026-07-07-fase4-microsservicos-design.md`. Contrato de integração via SSM: seção "Contrato de Integração" do `README.md`.

## Transporte e topologia

Outbox por serviço → SNS (um tópico por produtor) → SQS (uma fila por consumidor, com DLQ). Provisionado em `modules/messaging/saga.tf`.

| Recurso | Nome |
|---|---|
| Tópico (por produtor) | `auto-repair-shop-{order\|billing\|execution}-events-{env}` |
| Fila (por consumidor) | `auto-repair-shop-{order\|billing\|execution}-queue-{env}` |
| DLQ | `auto-repair-shop-{service}-queue-dlq-{env}` (retenção 14 dias) |
| ARNs/URLs via SSM | `/auto-repair-shop/{env}/sns/{service}-events-topic-arn`, `/auto-repair-shop/{env}/sqs/{service}-queue-url` |

Regras da topologia:

- **Mesh completa, sem filtro por evento.** A fila de cada serviço assina os **dois** tópicos dos outros serviços por inteiro. Cada consumidor recebe um superset e **despacha por `eventType`, ignorando o que não trata** (marca como processado sem handler — igual ao `EventProcessor` do monólito). A única assinatura filtrada é a da Lambda de email (ver `QuoteEmailRequested`).
- **`raw_message_delivery = true`.** O body entregue na SQS é o envelope JSON cru (sem wrapper do SNS), e os message attributes do SNS chegam intactos como message attributes da SQS.
- **DLQ após 3 tentativas** (`maxReceiveCount = 3`), visibility timeout 60s.

## Envelope

Todo evento publicado tem este envelope no body (JSON):

```jsonc
{
  "eventId":      "uuid",        // idempotência; PK em processed_events
  "eventType":    "OrderCreated",// nome lógico estável (NÃO é class name Kotlin)
  "eventVersion": 1,             // inteiro; incrementa em mudança incompatível de payload
  "occurredAt":   "2026-07-18T14:03:00Z", // ISO-8601 UTC
  "payload":      { }            // ver catálogo
}
```

### Message attributes (SNS → SQS)

| Attribute | Valor | Uso |
|---|---|---|
| `eventType` | igual ao envelope (ex. `OrderCreated`) | **camelCase** — casa com o `filter_policy` da infra. O `SnsClient` do monólito publica `event_type` (snake_case) hoje; ao migrar, renomear para `eventType`. |
| `traceparent` | header W3C trace context | propagação de trace por SNS/SQS → Tempo (tracing distribuído) |

## Convenções

- JSON, chaves **camelCase**.
- Dinheiro: `BigDecimal` serializado como número decimal (ex. `149.90`) — igual ao código atual (`Service.price`, `SendQuoteEmailCommand.totalAmount`).
- Timestamps: ISO-8601 em UTC.
- **Idempotência:** dedup por `eventId` na tabela/registro `processed_events (event_id, consumer_id)` PK, por serviço. Já existe no monólito (`storage/.../ProcessedEvents.kt`); billing e execution replicam (execution em DynamoDB).
- **Correlação:** `orderId` é a chave da saga em **todo** evento. `reservationId` nasce no `PartsReserved`, billing persiste, e o devolve nas compensações que pedem liberação de reserva.
- **Versionamento:** todos começam em `eventVersion: 1`. Mudança compatível (campo aditivo opcional) não incrementa; mudança incompatível incrementa e o consumidor passa a tratar as duas versões durante a transição.

## Catálogo de eventos

| Evento | Produtor (tópico) | Consumidores | Peso |
|---|---|---|---|
| `OrderCreated` | order | execution | **gordo** |
| `PartsReserved` | execution | billing | **gordo** |
| `QuoteEmailRequested` | billing | Lambda de email (assinatura filtrada) | médio |
| `QuoteApproved` | billing | Lambda de email (assinatura filtrada) | médio |
| `PaymentConfirmed` | billing | order, execution | fino |
| `ExecutionStarted` | execution | order | fino |
| `DiagnoseFinished` | execution | order | fino |
| `ExecutionFinished` | execution | order | fino |
| `PartsUnavailable` | execution | order | fino |
| `QuoteRejected` | billing | execution, order | fino |
| `PaymentFailed` | billing | execution, order | fino |
| `ExecutionFailed` | execution | billing, order | fino |
| `ReservationExpired` | execution (job interno) | order | fino |

Fluxo feliz: `OrderCreated` → `PartsReserved` → `QuoteEmailRequested` → (cliente aprova via link → `QuoteApproved`, que leva o link de checkout ao e-mail) → `PaymentConfirmed` → `ExecutionStarted`/`DiagnoseFinished` → `ExecutionFinished`.

A reserva (`PartsReserved`) acontece **antes** do orçamento para eliminar a corrida entre estoque e pagamento — o cliente nunca paga por serviço inexequível.

### Eventos gordos (event-carried state transfer)

`OrderCreated` e `PartsReserved` carregam o estado necessário para que **nenhuma chamada REST** aconteça no fluxo da saga. billing só escuta `PartsReserved` (nunca `OrderCreated`); por isso execution **repassa o orçamento priced** adiante.

```jsonc
// OrderCreated  (order → execution)
{
  "orderId": "uuid",
  "customer": { "id": "uuid", "name": "string", "email": "string" },
  "vehicle":  { "plate": "string", "model": "string" },
  "services": [ { "id": "uuid", "name": "string", "price": 149.90 } ],
  "parts":    [ { "id": "uuid", "name": "string", "quantity": 2, "unitPrice": 30.00 } ],
  "totalAmount": 209.90
}
```

```jsonc
// PartsReserved  (execution → billing) — confirma reserva + repassa o quote priced
{
  "orderId": "uuid",
  "reservationId": "uuid",
  "customer": { "id": "uuid", "name": "string", "email": "string" },
  "services": [ { "name": "string", "price": 149.90 } ],
  "parts":    [ { "id": "uuid", "name": "string", "quantity": 2, "unitPrice": 30.00 } ],
  "totalAmount": 209.90
}
```

```jsonc
// QuoteEmailRequested  (billing → Lambda de email, filter_policy eventType)
{
  "orderId": "uuid",
  "customer": { "name": "string", "email": "string" },
  "totalAmount": 209.90,
  "services": [ { "name": "string", "price": 149.90 } ],
  "supplies": [ { "name": "string", "quantity": 2, "unitPrice": 30.00 } ],
  "approvalUrl": "https://.../v1/quotes/approve?token=...",
  "declineUrl": "https://.../v1/quotes/decline?token=..."
}
```

```jsonc
// QuoteApproved  (billing → Lambda de email, filter_policy eventType)
{
  "orderId": "uuid",
  "customer": { "name": "string", "email": "string" },
  "totalAmount": 209.90,
  "checkoutUrl": "https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=..."
}
```

### Eventos finos

Todos carregam `orderId`; os campos abaixo são adicionais.

```jsonc
// PaymentConfirmed  (billing → order, execution)
{ "orderId": "uuid", "paymentId": "string", "amount": 209.90 }

// ExecutionStarted / DiagnoseFinished / ExecutionFinished  (execution → order)
{ "orderId": "uuid" }

// PartsUnavailable  (execution → order) — order cancela a OS
{ "orderId": "uuid",
  "missingParts": [ { "id": "uuid", "name": "string", "requested": 3, "available": 1 } ] }

// QuoteRejected  (billing → execution, order) — execution libera reserva; order cancela
{ "orderId": "uuid", "reservationId": "uuid" }

// PaymentFailed  (billing → execution, order) — execution libera reserva; order cancela
{ "orderId": "uuid", "reservationId": "uuid", "reason": "string" }

// ExecutionFailed  (execution → billing, order) — billing estorna via MP; order cancela
{ "orderId": "uuid", "paymentId": "string", "reason": "string" }

// ReservationExpired  (execution job interno → order) — execution libera; order cancela
{ "orderId": "uuid", "reservationId": "uuid" }
```

## Resumo por serviço (o corte de cada sessão)

### order
- **Produz:** `OrderCreated`.
- **Consome:** `PaymentConfirmed`, `QuoteRejected`, `PaymentFailed` (billing); `ExecutionStarted`, `DiagnoseFinished`, `ExecutionFinished`, `PartsUnavailable`, `ExecutionFailed`, `ReservationExpired` (execution).
- Deriva o estado da saga do status da OS (sem orquestrador). Compensações → OS `CANCELED`.

### billing
- **Produz:** `QuoteEmailRequested`, `QuoteApproved`, `PaymentConfirmed`, `QuoteRejected`, `PaymentFailed`.
- **Consome:** `PartsReserved` (execution), `ExecutionFailed` (execution → estorno via MP).
- Persiste `reservationId` do `PartsReserved` para devolver nas compensações. Cria a preferência MP no clique de aprovação, redireciona 302 ao checkout e publica `QuoteApproved` com o `checkoutUrl`; confirma via webhook `POST /v1/webhooks/mercadopago`.

### execution
- **Produz:** `PartsReserved`, `ExecutionStarted`, `DiagnoseFinished`, `ExecutionFinished`, `PartsUnavailable`, `ExecutionFailed`, `ReservationExpired`.
- **Consome:** `OrderCreated` (order); `PaymentConfirmed`, `QuoteRejected`, `PaymentFailed` (billing).
- Gera `reservationId` no `PartsReserved`; libera reserva por `reservationId` nas compensações e no job de expiração.
