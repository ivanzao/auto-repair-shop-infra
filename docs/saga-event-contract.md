# Contrato de Eventos da Saga (Fase 4)

Fonte única de verdade para a comunicação assíncrona entre os serviços **order**, **billing** e **execution**. Os três repos consomem este documento; qualquer mudança de payload, nome de evento ou topologia começa aqui.

Contexto de design: `docs/superpowers/specs/2026-07-07-fase4-microsservicos-design.md`. O diagnóstico no execution e o order como read model da saga estão em `docs/superpowers/specs/2026-07-25-diagnostico-no-execution-design.md`, com os payloads congelados em `docs/superpowers/plans/2026-07-25-diagnostico-0-contrato.md` (ambos no repo `auto-repair-shop-billing`). Contrato de integração via SSM: seção "Contrato de Integração" do `README.md`.

## Transporte e topologia

Outbox por serviço → SNS (um tópico por produtor) → SQS (uma fila por consumidor, com DLQ). Provisionado em `modules/messaging/services.tf`.

| Recurso | Nome |
|---|---|
| Tópico (por produtor) | `auto-repair-shop-{order\|billing\|execution}-events-{env}` |
| Fila (por consumidor) | `auto-repair-shop-{order\|billing\|execution}-queue-{env}` |
| DLQ | `auto-repair-shop-{service}-queue-dlq-{env}` (retenção 14 dias) |
| ARNs/URLs via SSM | `/auto-repair-shop/{env}/sns/{service}-events-topic-arn`, `/auto-repair-shop/{env}/sqs/{service}-queue-url` |

Regras da topologia:

- **Mesh completa, sem filtro por evento.** A fila de cada serviço assina os **dois** tópicos dos outros serviços por inteiro. Cada consumidor recebe um superset e **despacha por `eventType`, ignorando o que não trata** (marca como processado sem handler). A única assinatura filtrada é a da Lambda de email (ver `QuoteEmailRequested`).
- **`raw_message_delivery = true`.** O body entregue na SQS é o envelope JSON cru (sem wrapper do SNS), e os message attributes do SNS chegam intactos como message attributes da SQS.
- **DLQ após 3 tentativas** (`maxReceiveCount = 3`), visibility timeout 60s.
- **Evento novo não é infra nova.** Como a mesh é gerada por produto cartesiano sobre a lista de serviços e não há `filter_policy` entre eles, acrescentar, renomear ou remover um `eventType` é mudança de aplicação. Só a assinatura da Lambda de email precisa de Terraform quando muda a lista de eventos que ela recebe.

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
| `eventType` | igual ao envelope (ex. `OrderCreated`) | **camelCase**, casando com o `filter_policy` da infra |
| `traceparent` | header W3C trace context | propagação de trace por SNS/SQS → Tempo (tracing distribuído) |

## Identidade nos eventos

Não há validação contra banco: os serviços confiam no JWT, que já carrega `sub`, `role` e `cpf`. Uma única representação, `User(id, document)`, preenchida a partir do token de quem fez a chamada:

| Onde | Campo | Origem |
|---|---|---|
| `Order` | `openedBy` | JWT de quem chamou `POST /v1/orders` |
| `Execution` | `diagnosedBy` | JWT de quem chamou `finish-diagnosis` |

Só o `diagnosedBy` atravessa a fronteira, dentro do `DiagnoseFinished`. Consequência para a infra: **nenhuma**. A aplicação Kotlin parseia o próprio `Authorization: Bearer`, que o API Gateway repassa intacto, e não depende dos headers `X-User-Id`/`X-User-Role` injetados pelo authorizer. Consequência para as migrations: não existe mais acoplamento de UUID entre repositórios; a `V3` do lambdas semeia usuários e ninguém precisa parear nada.

## Convenções

- JSON, chaves **camelCase**.
- Dinheiro: `BigDecimal` serializado como número decimal (ex. `149.90`).
- Timestamps: ISO-8601 em UTC.
- Placa: formato antigo, `^[A-Z]{3}\d{4}$` (ex. `ABC1234`). O `VehiclePlate` do order **rejeita placa Mercosul**; aceitar o formato novo seria decisão de produto.
- **Idempotência:** dedup por `eventId` na tabela/registro `processed_events (event_id, consumer_id)` PK, por serviço. billing e execution replicam o padrão do order (execution em DynamoDB).
- **Correlação:** `orderId` é a chave da saga em **todo** evento. `reservationId` nasce no `DiagnoseFinished` (execution), é repassado pelo order dentro do `OrderAwaitingApproval`, o billing persiste, e o devolve nas compensações que pedem liberação de reserva.
- **Vocabulário:** `mechanic`, nunca `technician`. `supplies`, nunca `parts`.
- **Versionamento:** todos começam em `eventVersion: 1`. Mudança compatível (campo aditivo opcional) não incrementa; mudança incompatível incrementa e o consumidor passa a tratar as duas versões durante a transição. `OrderCreated` e `SuppliesUnavailable` mudaram de formato ou de nome na entrega do diagnóstico e **permanecem em `eventVersion: 1`**: não existe consumidor com o formato antigo fora da janela de deploy, que é coordenada na ordem execution → order → billing. Durante a janela a saga trava na etapa correspondente sem perder mensagem: elas ficam na fila e são reprocessadas.

## Catálogo de eventos

| Evento | Produtor (tópico) | Consumidores | Peso |
|---|---|---|---|
| `OrderCreated` | order | execution | médio |
| `DiagnoseFinished` | execution | order | **gordo** |
| `OrderAwaitingApproval` | order | billing | **gordo** |
| `QuoteEmailRequested` | billing | Lambda de email (assinatura filtrada) | médio |
| `QuoteApproved` | billing | Lambda de email (assinatura filtrada) | médio |
| `PaymentConfirmed` | billing | order, execution | fino |
| `ExecutionStarted` | execution | order | fino |
| `ExecutionFinished` | execution | order | fino |
| `SuppliesUnavailable` | execution | order | fino |
| `QuoteRejected` | billing | execution, order | fino |
| `PaymentFailed` | billing | execution, order | fino |
| `ExecutionFailed` | execution | billing, order | fino |
| `ReservationExpired` | execution (job interno) | order | fino |

Fluxo feliz: `OrderCreated` → (o mecânico pega a OS da fila e chama `POST /v1/orders/{orderId}/finish-diagnosis` no execution) → `DiagnoseFinished` → `OrderAwaitingApproval` → `QuoteEmailRequested` → (cliente aprova via link → `QuoteApproved`, que leva o link de checkout ao e-mail) → `PaymentConfirmed` → (o mecânico chama `POST /v1/orders/{orderId}/start`) → `ExecutionStarted` → `ExecutionFinished`.

O diagnóstico resolve preços e reserva estoque **na mesma operação**, e é o `DiagnoseFinished` que anuncia as duas coisas. A reserva acontece **antes** do orçamento para eliminar a corrida entre estoque e pagamento, para que o cliente nunca pague por serviço inexequível.

`OrderAwaitingApproval` declara um fato, não dá uma ordem: o order não sabe que existe alguém encarregado de gerar orçamento. `QuoteRequested` seria comando disfarçado.

### Eventos gordos (event-carried state transfer)

`OrderCreated`, `DiagnoseFinished` e `OrderAwaitingApproval` carregam o estado necessário para que **nenhuma chamada REST** aconteça no fluxo da saga. O billing só escuta `OrderAwaitingApproval` (nunca `OrderCreated`, nunca `DiagnoseFinished`); por isso o order **repassa o orçamento priced** adiante.

```jsonc
// OrderCreated  (order → execution): enfileira a OS para diagnóstico
{
  "orderId": "uuid",
  "customer": { "id": "uuid", "name": "string", "email": "string" },
  "vehicle":  { "plate": "ABC1234", "model": "string" }
}
```

```jsonc
// DiagnoseFinished  (execution → order): preços resolvidos + estoque reservado
{
  "orderId": "uuid",
  "reservationId": "uuid",
  "diagnosedBy": { "id": "uuid", "document": "string" },
  "customer": { "name": "string", "email": "string" },
  "services": [ { "id": "uuid", "name": "string", "price": 149.90 } ],
  "supplies": [ { "id": "uuid", "name": "string", "quantity": 2, "unitPrice": 30.00 } ],
  "totalAmount": 209.90
}
```

`totalAmount` = soma de `price` dos serviços + soma de `quantity × unitPrice` dos insumos. Os preços são resolvidos pelo catálogo e pelo estoque do execution; o order não conhece catálogo nem preço e grava o que chega como snapshot.

```jsonc
// OrderAwaitingApproval  (order → billing): gatilho da quote
{
  "orderId": "uuid",
  "reservationId": "uuid",
  "customer": { "name": "string", "email": "string" },
  "services": [ { "id": "uuid", "name": "string", "price": 149.90 } ],
  "supplies": [ { "id": "uuid", "name": "string", "quantity": 2, "unitPrice": 30.00 } ],
  "totalAmount": 209.90
}
```

O `diagnosedBy` **não** é repassado: é informação de oficina, e o billing não tem uso para ela.

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

// ExecutionStarted  (execution → order): emitido por POST /v1/orders/{id}/start
{ "orderId": "uuid" }

// ExecutionFinished  (execution → order): emitido por POST /v1/orders/{id}/finish
{ "orderId": "uuid" }

// SuppliesUnavailable  (execution → order): order cancela a OS
{ "orderId": "uuid",
  "missingSupplies": [
    { "supplyId": "uuid", "name": "string", "requested": 4, "available": 1 } ] }

// QuoteRejected  (billing → execution, order): execution libera reserva; order cancela
{ "orderId": "uuid", "reservationId": "uuid" }

// PaymentFailed  (billing → execution, order): execution libera reserva; order cancela
{ "orderId": "uuid", "reservationId": "uuid", "reason": "string" }

// ExecutionFailed  (execution → billing, order): billing estorna via MP; order cancela
{ "orderId": "uuid", "paymentId": "string", "reason": "string" }

// ReservationExpired  (execution job interno → order): execution libera; order cancela
{ "orderId": "uuid", "reservationId": "uuid" }
```

`ExecutionStarted` mudou de gatilho, não de payload: deixou de sair junto com o `PaymentConfirmed` e passa a ser emitido quando o mecânico inicia a execução. É o que faz a fila existir de verdade.

### Eventos removidos

| Evento | O que aconteceu |
|---|---|
| `SuppliesReserved` | **removido.** A reserva passou a acontecer dentro do `finish-diagnosis`, e o fato é anunciado pelo `DiagnoseFinished`. Um evento a menos no caminho feliz. |
| `DiagnoseFinished` (significado antigo) | **removido.** Era a transição pós-pagamento `IN_PROGRESS → DIAGNOSED`, que nunca correspondeu a um diagnóstico de verdade. Some junto com o estado `DIAGNOSED`; **o nome foi reusado** para o evento de fim de diagnóstico. |
| `PartsUnavailable` | **renomeado** para `SuppliesUnavailable`, alinhando com o vocabulário `supplies`. O payload não mudou: é `missingSupplies` com `supplyId`, `name`, `requested` e `available`, exatamente como o código sempre emitiu. |
| `PartsReserved` | nunca existiu no código: era como este documento chamava, por engano, o `SuppliesReserved`, que por sua vez também deixou de existir. |

Não há, e nunca houve, `DiagnosisStarted`: o mecânico não assume a OS num passo separado. Ele a pega da fila e conclui o diagnóstico numa chamada só, e é aí que o `diagnosedBy` é capturado.

## Máquinas de estado

### order

```
RECEIVED → WAITING_APPROVAL → EXECUTION_ENQUEUED → IN_PROGRESS → COMPLETED → DELIVERED
```

| Transição | Disparada por |
|---|---|
| `RECEIVED → WAITING_APPROVAL` | `DiagnoseFinished` |
| `WAITING_APPROVAL → EXECUTION_ENQUEUED` | `PaymentConfirmed` |
| `EXECUTION_ENQUEUED → IN_PROGRESS` | `ExecutionStarted` |
| `IN_PROGRESS → COMPLETED` | `ExecutionFinished` |
| `COMPLETED → DELIVERED` | retirada, rota local |
| qualquer não terminal `→ CANCELED` | `SuppliesUnavailable`, `QuoteRejected`, `PaymentFailed`, `ExecutionFailed`, `ReservationExpired` |

Não há `IN_DIAGNOSIS`: sem evento de início de diagnóstico, não há gatilho. `RECEIVED` já significa "aguardando diagnóstico".

### execution

```
AWAITING_DIAGNOSIS → RESERVED → ENQUEUED → IN_PROGRESS → COMPLETED
```

| Transição | Disparada por |
|---|---|
| `AWAITING_DIAGNOSIS → RESERVED` | `POST /v1/orders/{id}/finish-diagnosis` |
| `RESERVED → ENQUEUED` | `PaymentConfirmed` |
| `ENQUEUED → IN_PROGRESS` | `POST /v1/orders/{id}/start` |
| `IN_PROGRESS → COMPLETED` | `POST /v1/orders/{id}/finish` |
| `IN_PROGRESS → FAILED` | `POST /v1/orders/{id}/fail` |
| `AWAITING_DIAGNOSIS`, `RESERVED` ou `ENQUEUED` `→ CANCELED` | falta de estoque no próprio diagnóstico, `QuoteRejected`, `PaymentFailed` |

`DIAGNOSED` é removido. `ENQUEUED` passa a ser **persistido de verdade**: as transições de enfileiramento e de início eram feitas numa expressão só, e por isso o estado nunca existia no banco e a consulta por status devolvia lista vazia. Separá-las é o que cria a fila.

O execution diz `ENQUEUED` e o order diz `EXECUTION_ENQUEUED` para o mesmo instante. É deliberado: o nome do status da OS diz **o que** está enfileirado. Não "corrigir".

### billing

Inalterada: `PENDING_APPROVAL → APPROVED → PAID | PAYMENT_FAILED`, mais `REJECTED` e `REFUNDED`. Muda só o gatilho de criação da quote, que passa de `SuppliesReserved` para `OrderAwaitingApproval`.

## Resumo por serviço (o corte de cada sessão)

### order
- **Produz:** `OrderCreated`, `OrderAwaitingApproval`.
- **Consome:** `DiagnoseFinished`, `SuppliesUnavailable`, `ExecutionStarted`, `ExecutionFinished`, `ExecutionFailed`, `ReservationExpired` (execution); `PaymentConfirmed`, `QuoteRejected`, `PaymentFailed` (billing).
- Read model da saga: dono do ciclo de vida da OS (abertura, status, histórico), sem catálogo nem preço próprios. Grava como snapshot os itens precificados que chegam no `DiagnoseFinished` e os repassa no `OrderAwaitingApproval`. Compensações → OS `CANCELED`.

### billing
- **Produz:** `QuoteEmailRequested`, `QuoteApproved`, `PaymentConfirmed`, `QuoteRejected`, `PaymentFailed`.
- **Consome:** `OrderAwaitingApproval` (order), `ExecutionFailed` (execution → estorno via MP).
- Persiste o `reservationId` que chega no `OrderAwaitingApproval` para devolver nas compensações. Cria a preferência MP no clique de aprovação, redireciona 302 ao checkout e publica `QuoteApproved` com o `checkoutUrl`; confirma via webhook `POST /v1/webhooks/mercadopago`.

### execution
- **Produz:** `DiagnoseFinished`, `SuppliesUnavailable`, `ExecutionStarted`, `ExecutionFinished`, `ExecutionFailed`, `ReservationExpired`.
- **Consome:** `OrderCreated` (order); `PaymentConfirmed`, `QuoteRejected`, `PaymentFailed` (billing).
- Dono do catálogo de serviços, do estoque de insumos, do diagnóstico e da fila de execução. Gera o `reservationId` no `DiagnoseFinished`; libera reserva por `reservationId` nas compensações e no job de expiração.
