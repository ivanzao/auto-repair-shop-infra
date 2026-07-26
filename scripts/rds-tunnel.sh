#!/usr/bin/env bash
# rds-tunnel.sh — abre um tunnel local → RDS via pod socat no EKS
#
# Uso:
#   ./scripts/rds-tunnel.sh <order|billing|auth> [prod|hml]
#
# Resultado:
#   Banco acessível em localhost com qualquer client (IntelliJ, DBeaver, psql).
#   Cada serviço tem porta local própria, então dá para abrir os três ao mesmo tempo.
#   O pod de tunnel é removido automaticamente ao sair (Ctrl+C).
#
# execution não aparece aqui: usa DynamoDB, não RDS.
#
# Pré-requisitos: aws cli, kubectl, jq
# Credenciais AWS resolvidas pela cadeia padrão do CLI (aws configure / ~/.aws/credentials / env vars)

set -euo pipefail

SERVICE="${1:-}"
ENV="${2:-prod}"

if [[ "$SERVICE" == "execution" ]]; then
  echo "execution usa DynamoDB, não RDS. Consulte com:" >&2
  echo "  aws dynamodb scan --table-name auto-repair-shop-execution-$ENV --max-items 20" >&2
  exit 1
fi

if [[ "$SERVICE" != "order" && "$SERVICE" != "billing" && "$SERVICE" != "auth" ]]; then
  echo "uso: $0 <order|billing|auth> [prod|hml]" >&2
  exit 1
fi

if [[ "$ENV" != "prod" && "$ENV" != "hml" ]]; then
  echo "uso: $0 <order|billing|auth> [prod|hml]" >&2
  exit 1
fi

case "$SERVICE" in
  order)   LOCAL_PORT=15432 ;;
  billing) LOCAL_PORT=15433 ;;
  auth)    LOCAL_PORT=15434 ;;
esac

NAMESPACE="auto-repair-shop-$ENV"
POD_NAME="rds-tunnel-$SERVICE-$$"

echo "→ buscando credenciais do RDS ($SERVICE/$ENV)..."

SECRET_ARN=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/$SERVICE/db/secret-arn" \
  --query Parameter.Value --output text)

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString --output text)

RDS_HOST=$(echo "$SECRET_JSON" | jq -r .host)
RDS_PORT=$(echo "$SECRET_JSON" | jq -r .port)
DB_NAME=$(echo "$SECRET_JSON"  | jq -r .dbname)
DB_USER=$(echo "$SECRET_JSON"  | jq -r .username)
DB_PASS=$(echo "$SECRET_JSON"  | jq -r .password)

CLUSTER_NAME=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/eks/cluster-name" \
  --query Parameter.Value --output text)

echo "→ atualizando kubeconfig para $CLUSTER_NAME..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "${AWS_DEFAULT_REGION:-us-east-1}" 2>/dev/null

cleanup() {
  echo ""
  echo "→ removendo pod $POD_NAME..."
  kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "→ criando pod tunnel ($POD_NAME)..."
kubectl run "$POD_NAME" \
  --image=alpine/socat \
  --restart=Never \
  --namespace="$NAMESPACE" \
  -- socat TCP-LISTEN:"$RDS_PORT",fork TCP:"$RDS_HOST":"$RDS_PORT" >/dev/null 2>&1

echo "→ aguardando pod ficar Ready..."
kubectl wait pod "$POD_NAME" \
  --for=condition=Ready \
  --namespace="$NAMESPACE" \
  --timeout=60s >/dev/null

cat <<EOF

╔═══════════════════════════════════════════════════════════════════
║  Tunnel ativo — $SERVICE ($ENV)
╠═══════════════════════════════════════════════════════════════════
║  IntelliJ / DBeaver — Data Source PostgreSQL:
║
║    jdbc:postgresql://localhost:$LOCAL_PORT/$DB_NAME
║
║    host:     localhost
║    port:     $LOCAL_PORT
║    database: $DB_NAME
║    user:     $DB_USER
║    password: $DB_PASS
║
║  psql rápido:
║    PGPASSWORD='$DB_PASS' psql -h localhost -p $LOCAL_PORT -U $DB_USER -d $DB_NAME
║
║  Portas por serviço: order 15432 · billing 15433 · auth 15434
║  Ctrl+C encerra e remove o pod
╚═══════════════════════════════════════════════════════════════════

EOF

kubectl port-forward "pod/$POD_NAME" \
  "$LOCAL_PORT":"$RDS_PORT" \
  --namespace="$NAMESPACE"
