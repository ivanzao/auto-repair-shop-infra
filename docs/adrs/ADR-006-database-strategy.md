# ADR-006 — Estratégia de bancos PostgreSQL e DynamoDB

**Status:** Aceito em 2026-05-25, revisado na separação em microsserviços

## Contexto

O domínio nasceu monolítico e **fortemente relacional**: cliente possui veículos, veículo tem múltiplas ordens de serviço, cada OS tem serviços e insumos. Havia ainda tabelas operacionais: outbox de eventos, idempotência e locks distribuídos via ShedLock.

Com a separação em microsserviços, a pergunta deixou de ser "qual banco para o sistema" e passou a ser "qual banco para cada serviço". Cada um tem padrão de acesso próprio e nenhum lê o banco do outro.

## Opções consideradas

### Opção A: PostgreSQL gerenciado via RDS (escolhida para order e billing)

**Prós**:
- ACID transacional, necessário para o outbox: mudança de estado e evento gravados na mesma transação
- UUID nativo, JSONB para payload de eventos, CHECK constraints, índices parciais
- Ecossistema rico na JVM: Exposed, Flyway, HikariCP
- RDS gerencia backup, encryption-at-rest e failover

**Contras**:
- Custo de instância 24/7, mitigado pelos créditos do AWS Academy

### Opção B: MySQL/MariaDB gerenciado

**Prós**: maturidade similar ao Postgres.
**Contras**: JSONB do Postgres é mais performático; DDL do MySQL tem cantos ásperos (sem `CREATE INDEX IF NOT EXISTS`); Exposed pende para Postgres.
**Rejeitado**: nenhuma vantagem técnica clara.

### Opção C: DynamoDB (escolhida para execution)

**Prós**: serverless, escala automática, pay-per-request, escrita condicional e `TransactWriteItems`.
**Contras**: sem joins; consultas como "todas as OS deste cliente no período" exigem desnormalização agressiva e múltiplos GSI.

**Rejeitado como banco único**, porque as consultas relacionais do order não se acomodam bem nele. **Adotado para o execution**, cujo padrão de acesso é outro: acesso por chave e reserva de estoque sob condição, sem leitura prévia.

### Opção D: SQL Server (RDS)

**Contras**: custo de licença, ecossistema Linux/Kotlin menos otimizado.
**Rejeitado**: custo proibitivo.

### Opção E: Aurora Serverless v2 (compatível com PostgreSQL)

**Prós**: auto-scaling, paga pelo uso.
**Contras**: cold start de até 30s, custo mínimo de 0.5 ACU mesmo ocioso.
**Rejeitado**: complexidade extra sem retorno para a carga deste projeto.

## Recomendação

Persistência poliglota, uma escolha por serviço:

| Serviço | Banco | Motivo |
|---|---|---|
| order | PostgreSQL (RDS) | agregado relacional: OS, cliente, veículo, com integridade referencial |
| billing | PostgreSQL (RDS) | quotes e tokens, com transação abrangendo estado e outbox |
| execution | DynamoDB single-table | acesso por chave, escrita condicional e `TransactWriteItems` para a reserva atômica de estoque |

DynamoDB foi descartado como banco **único**, porque as consultas relacionais do order não se acomodam bem nele. Ao separar em microsserviços, cada serviço passou a escolher o seu, e o execution ganhou o banco que o padrão de acesso dele pede: reserva de estoque sob condição, sem leitura prévia.

Um quarto banco, PostgreSQL, guarda a tabela `users` e pertence ao repositório de lambdas.

Configuração dos RDS: uma instância por serviço e por ambiente, `db.t3.micro`, backup automático de 7 dias, encryption-at-rest com KMS default. Migrations via Flyway no próprio serviço; um job in-cluster cria roles e databases por ambiente, já que IAM auth é bloqueado no AWS Academy.

## Consequências

**Positivas**:
- O outbox transacional funciona nativamente nos dois paradigmas: transação no Postgres, `TransactWriteItems` no DynamoDB
- Cada serviço evolui o schema sem coordenar com os demais
- Cumpre a exigência de usar pelo menos um banco relacional e um não relacional

**Negativas**:
- Operar dois paradigmas exige **dois modelos de teste**: Testcontainers com Postgres para order e billing, LocalStack DynamoDB para execution
- Conhecimento de time dividido entre modelagem relacional e single-table design
- Sem consulta federada: qualquer visão que cruze serviços é composição via eventos, não join

**Mitigações**:
- Pool HikariCP por pod nos serviços relacionais
- No execution, o GSI esparso limita as varreduras dos jobs ao que interessa: reservas ativas e outbox pendente
