# ADR-003 — Lambda Authorizer injeta headers; app não revalida JWT

**Status:** Aceito em 2026-05-25

## Contexto

O JWT é assinado pelo Lambda login com um segredo `JWT_HMAC` por ambiente. Toda request para `/v1/*` passa pelo Lambda Authorizer no API Gateway. A questão é onde a identidade do usuário é extraída e como chega ao app downstream.

## Decisão

O Authorizer retorna `{ userId, role, cpf }` no contexto da resposta. O API Gateway injeta esses valores como `X-User-Id` e `X-User-Role` usando `overwrite:`, impedindo que clientes externos enviem esses headers diretamente. O app lê os headers e confia, sem conhecer o segredo JWT nem revalidar a assinatura.

## Consequências

- App não precisa do `JWT_HMAC`, o que reduz a superfície de ataque
- Cache de resultado do Authorizer (5 min) reduz invocações Lambda; revalidar no app seria overhead desperdiçado
- Mudar o formato de claims exige redeploy do Lambda e da configuração de integração no API Gateway
- Rotas públicas (aprovação de orçamento pelo cliente) não recebem os headers; usam token UUID single-use no banco como credencial
