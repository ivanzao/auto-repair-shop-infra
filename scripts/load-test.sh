#!/usr/bin/env bash
# load-test.sh: gera tráfego de negócio (orders/customers/supplies/services)
# contra a API pra popular dashboards Grafana (APM, Errors, Orders Operations).
#
# Uso:
#   ./scripts/load-test.sh [prod|hml] [num_orders]
#
# Pré-requisitos: aws cli, curl, jq
# Requer um admin pré-bootstrapped:
#   cpf=11144477735  password=admin123
# (criado via INSERT direto em users + attendants).

set -euo pipefail

ENV="${1:-prod}"
ORDERS_COUNT="${2:-10}"

if [[ "$ENV" != "prod" && "$ENV" != "hml" ]]; then
  echo "uso: $0 [prod|hml] [num_orders]" >&2
  exit 1
fi

ADMIN_CPF="11144477735"
ADMIN_PASS="admin123"

APIGW=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/apigw/endpoint" \
  --query Parameter.Value --output text)
APIGW="${APIGW%/}"
echo "→ API: $APIGW"

TOKEN=$(curl -fsS -X POST "$APIGW/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"cpf\":\"$ADMIN_CPF\",\"password\":\"$ADMIN_PASS\"}" \
  | jq -r .token)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "✗ login falhou" >&2; exit 1
fi
echo "→ JWT obtido"

auth_post() {
  curl -fsS -X POST "$1" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$2"
}

echo ""
echo "→ supplies"
SUPPLY1=$(auth_post "$APIGW/v1/supplies" '{"name":"Óleo 5W30","description":"1L","quantity":100,"price":45.00}' | jq -r .id)
SUPPLY2=$(auth_post "$APIGW/v1/supplies" '{"name":"Filtro de óleo","description":"Universal","quantity":50,"price":22.50}' | jq -r .id)
echo "  $SUPPLY1"
echo "  $SUPPLY2"

echo ""
echo "→ services"
SVC1=$(auth_post "$APIGW/v1/services" \
  "{\"name\":\"Troca de óleo\",\"description\":\"Óleo + filtro\",\"price\":150.00,\"requiredSupplies\":[{\"supplyId\":\"$SUPPLY1\",\"quantity\":1},{\"supplyId\":\"$SUPPLY2\",\"quantity\":1}]}" | jq -r .id)
SVC2=$(auth_post "$APIGW/v1/services" \
  "{\"name\":\"Revisão geral\",\"description\":\"Inspeção 50 itens\",\"price\":400.00,\"requiredSupplies\":[]}" | jq -r .id)
echo "  $SVC1"
echo "  $SVC2"

NAMES=("João Silva" "Maria Souza" "Pedro Oliveira" "Ana Costa" "Lucas Martins")
RUN_TAG=$(printf '%05d' $((RANDOM % 100000)))
PLATE_PREFIXES=(TST QAR LDX FZP UVW)

CUSTOMERS=()
VEHICLES=()

echo ""
echo "→ customers + vehicles (run tag: $RUN_TAG)"
for i in "${!NAMES[@]}"; do
  DOC=$(printf '2%010d' $((RANDOM * RANDOM % 9999999990 + 1)) | head -c 11)
  PLATE="${PLATE_PREFIXES[$i]}$(printf '%04d' $((RANDOM % 10000)))"
  CUS=$(auth_post "$APIGW/v1/customers" \
    "{\"name\":\"${NAMES[$i]} $RUN_TAG\",\"document\":\"$DOC\",\"email\":\"cliente${i}_${RUN_TAG}@dev.com\",\"contact\":\"11999000$(printf '%02d' "$i")0\"}" \
    | jq -r .id)
  VEH=$(auth_post "$APIGW/v1/vehicles" \
    "{\"clientId\":\"$CUS\",\"plate\":\"$PLATE\",\"brand\":\"VW\",\"model\":\"Gol\",\"year\":$((2018 + i))}" \
    | jq -r .id)
  CUSTOMERS+=("$CUS")
  VEHICLES+=("$VEH")
  echo "  $CUS  /  $VEH  ($DOC / $PLATE)"
done

echo ""
echo "→ creating $ORDERS_COUNT orders + state transitions"
SUCCESS=0
FAIL=0
for i in $(seq 1 "$ORDERS_COUNT"); do
  idx=$(( (i - 1) % ${#CUSTOMERS[@]} ))
  CUS="${CUSTOMERS[$idx]}"
  VEH="${VEHICLES[$idx]}"
  SVC=$([ $((i % 2)) -eq 0 ] && echo "$SVC1" || echo "$SVC2")

  ORDER_ID=$(auth_post "$APIGW/v1/orders" \
    "{\"customerId\":\"$CUS\",\"vehicleId\":\"$VEH\",\"description\":\"OS #$i diagnóstico\",\"technician\":\"Téc $((i % 3 + 1))\",\"servicesIds\":[\"$SVC\"]}" \
    | jq -r .id || true)

  if [ -z "$ORDER_ID" ] || [ "$ORDER_ID" = "null" ]; then
    FAIL=$((FAIL + 1))
    continue
  fi
  SUCCESS=$((SUCCESS + 1))

  auth_post "$APIGW/v1/orders/$ORDER_ID/start-diagnosis" \
    "{\"technician\":\"Téc Alpha\"}" > /dev/null || true

  if (( i % 2 == 0 )); then
    auth_post "$APIGW/v1/orders/$ORDER_ID/finish-diagnosis" \
      "{\"servicesIds\":[\"$SVC\"]}" > /dev/null || true
  fi

  printf '\r  %d/%d (ok=%d fail=%d)' "$i" "$ORDERS_COUNT" "$SUCCESS" "$FAIL"
  sleep 0.1
done
echo ""

echo ""
echo "✓ Concluído"
echo "  customers/vehicles: ${#CUSTOMERS[@]}"
echo "  orders criadas:     $SUCCESS"
echo "  orders falhadas:    $FAIL"
echo ""
echo "Abra http://localhost:3000 → folder 'Auto Repair Shop' (range: Last 15 minutes)."
