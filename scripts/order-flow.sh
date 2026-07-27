#!/usr/bin/env bash
# order-flow.sh: executa o fluxo completo de 1 order:
#   login → create supply/service/customer/vehicle → create order
#   → start-diagnosis → finish-diagnosis → quote approve → complete → deliver
#
# Uso:
#   ./scripts/order-flow.sh [prod|hml] <cpf> <senha>
#
# Pré-requisitos: aws cli, kubectl, curl, jq

set -euo pipefail

ENV="${1:-prod}"
CPF="${2:?uso: $0 [prod|hml] <cpf> <senha>}"
PASS="${3:?uso: $0 [prod|hml] <cpf> <senha>}"

if [[ "$ENV" != "prod" && "$ENV" != "hml" ]]; then
  echo "uso: $0 [prod|hml] <cpf> <senha>" >&2
  exit 1
fi

NAMESPACE="auto-repair-shop-$ENV"

APIGW=$(aws ssm get-parameter --name "/auto-repair-shop/$ENV/apigw/endpoint" --query Parameter.Value --output text)
APIGW="${APIGW%/}"
echo "→ API: $APIGW"

TOKEN=$(curl -fsS -X POST "$APIGW/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"cpf\":\"$CPF\",\"password\":\"$PASS\"}" | jq -r .token)
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || { echo "✗ login falhou" >&2; exit 1; }
echo "→ JWT obtido"

auth_post() {
  curl -fsS -X POST "$1" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$2"
}
auth_get() {
  curl -fsS -H "Authorization: Bearer $TOKEN" "$1"
}

RUN=$(printf '%05d' $((RANDOM % 100000)))
DOC=$(printf '2%010d' $((RANDOM * RANDOM % 9999999990 + 1)) | head -c 11)
PLATE="OFL$(printf '%04d' $((RANDOM % 10000)))"

echo ""
echo "→ supply"
SUPPLY=$(auth_post "$APIGW/v1/supplies" "{\"name\":\"Óleo 5W30 ($RUN)\",\"description\":\"1L\",\"quantity\":100,\"price\":45.00}" | jq -r .id)
echo "  $SUPPLY"

echo "→ service (com supply requirement)"
SERVICE=$(auth_post "$APIGW/v1/services" \
  "{\"name\":\"Troca de óleo ($RUN)\",\"description\":\"Óleo + verificação\",\"price\":150.00,\"requiredSupplies\":[{\"supplyId\":\"$SUPPLY\",\"quantity\":1}]}" | jq -r .id)
echo "  $SERVICE"

echo "→ customer + vehicle"
CUSTOMER=$(auth_post "$APIGW/v1/customers" "{\"name\":\"Cliente $RUN\",\"document\":\"$DOC\",\"email\":\"cliente_$RUN@dev.com\",\"contact\":\"11999990001\"}" | jq -r .id)
VEHICLE=$(auth_post "$APIGW/v1/vehicles" "{\"clientId\":\"$CUSTOMER\",\"plate\":\"$PLATE\",\"brand\":\"VW\",\"model\":\"Gol\",\"year\":2022}" | jq -r .id)
echo "  customer=$CUSTOMER vehicle=$VEHICLE"

echo ""
echo "→ create order"
ORDER=$(auth_post "$APIGW/v1/orders" \
  "{\"customerId\":\"$CUSTOMER\",\"vehicleId\":\"$VEHICLE\",\"description\":\"Diagnóstico inicial ($RUN)\",\"technician\":\"Téc 1\",\"servicesIds\":[\"$SERVICE\"]}" \
  | jq -r .id)
echo "  $ORDER"

echo "→ start-diagnosis"
auth_post "$APIGW/v1/orders/$ORDER/start-diagnosis" '{"technician":"Téc Alpha"}' > /dev/null
echo "  IN_DIAGNOSIS"

echo "→ finish-diagnosis"
auth_post "$APIGW/v1/orders/$ORDER/finish-diagnosis" '{"servicesIds":[],"extraSuppliesRequests":[]}' > /dev/null
echo "  WAITING_APPROVAL"

echo ""
echo "→ buscando approval token no DB ..."
DB_SECRET_ARN=$(aws ssm get-parameter --name "/auto-repair-shop/$ENV/db/secret-arn" --query Parameter.Value --output text)
DB_JSON=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text)
DB_HOST=$(echo "$DB_JSON" | jq -r .host)
DB_USER=$(echo "$DB_JSON" | jq -r .username)
DB_PASS=$(echo "$DB_JSON" | jq -r .password)
DB_NAME=$(echo "$DB_JSON" | jq -r .dbname)

APPROVAL_TOKEN=$(kubectl run "psql-token-$$" -n "$NAMESPACE" \
  --rm -i --restart=Never --image=postgres:16-alpine \
  --env="PGHOST=$DB_HOST" --env="PGUSER=$DB_USER" \
  --env="PGPASSWORD=$DB_PASS" --env="PGDATABASE=$DB_NAME" -q \
  --command -- psql -At -v ON_ERROR_STOP=1 -c \
  "SELECT id FROM order_approval_tokens WHERE order_id = '$ORDER' AND used_at IS NULL ORDER BY created_at DESC LIMIT 1;" 2>/dev/null \
  | head -1 | tr -d '[:space:]')

if [ -z "$APPROVAL_TOKEN" ]; then
  echo "✗ approval token não encontrado para order $ORDER" >&2
  exit 1
fi
echo "  token=$APPROVAL_TOKEN"

echo "→ approve quote (rota pública)"
curl -fsS "$APIGW/v1/orders/quote/approve?token=$APPROVAL_TOKEN" > /dev/null
echo "  IN_PROGRESS"

echo "→ complete"
auth_post "$APIGW/v1/orders/$ORDER/complete" '{}' > /dev/null
echo "  COMPLETED"

echo "→ deliver"
auth_post "$APIGW/v1/orders/$ORDER/deliver" '{}' > /dev/null
echo "  DELIVERED"

echo ""
STATUS=$(auth_get "$APIGW/v1/orders/$ORDER" | jq -r .status)
echo "✓ Final state: $STATUS  (order=$ORDER)"
