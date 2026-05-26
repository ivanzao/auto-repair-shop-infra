#!/usr/bin/env bash
# rds-tunnel.sh — abre um tunnel local → RDS via pod socat no EKS
#
# Uso:
#   ./scripts/rds-tunnel.sh [prod|hml]
#
# Resultado:
#   Banco acessível em localhost:5432 com qualquer client (psql, DBeaver, etc.)
#   O pod de tunnel é removido automaticamente ao sair (Ctrl+C).
#
# Pré-requisitos: aws cli, kubectl, jq
# Credenciais AWS resolvidas pela cadeia padrão do CLI (aws configure / ~/.aws/credentials / env vars)

set -euo pipefail

ENV="${1:-prod}"

if [[ "$ENV" != "prod" && "$ENV" != "hml" ]]; then
  echo "uso: $0 [prod|hml]" >&2
  exit 1
fi

NAMESPACE="auto-repair-shop-$ENV"
POD_NAME="rds-tunnel-$$"
LOCAL_PORT=5432

# ── credenciais AWS ─────────────────────────────────────────────────────────
echo "→ buscando credenciais do RDS ($ENV)..."

SECRET_ARN=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/db/secret-arn" \
  --query Parameter.Value --output text)

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString --output text)

RDS_HOST=$(echo "$SECRET_JSON" | jq -r .host)
RDS_PORT=$(echo "$SECRET_JSON" | jq -r .port)
DB_NAME=$(echo "$SECRET_JSON"  | jq -r .dbname)
DB_USER=$(echo "$SECRET_JSON"  | jq -r .username)
DB_PASS=$(echo "$SECRET_JSON"  | jq -r .password)

# ── kubeconfig ──────────────────────────────────────────────────────────────
CLUSTER_NAME=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/eks/cluster-name" \
  --query Parameter.Value --output text)

echo "→ atualizando kubeconfig para $CLUSTER_NAME..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "${AWS_DEFAULT_REGION:-us-east-1}" 2>/dev/null

# ── cleanup ao sair ─────────────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "→ removendo pod $POD_NAME..."
  kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── pod socat ───────────────────────────────────────────────────────────────
echo "→ criando pod tunnel ($POD_NAME)..."
kubectl run "$POD_NAME" \
  --image=alpine/socat \
  --restart=Never \
  --namespace="$NAMESPACE" \
  -- socat TCP-LISTEN:5432,fork TCP:"$RDS_HOST":"$RDS_PORT" >/dev/null 2>&1

echo "→ aguardando pod ficar Ready..."
kubectl wait pod "$POD_NAME" \
  --for=condition=Ready \
  --namespace="$NAMESPACE" \
  --timeout=30s >/dev/null

# ── port-forward ─────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Tunnel ativo — conecte com qualquer client:        ║"
echo "║                                                      ║"
echo "║  host:     localhost                                 ║"
printf  "║  port:     %-41s║\n" "$LOCAL_PORT"
printf  "║  database: %-41s║\n" "$DB_NAME"
printf  "║  user:     %-41s║\n" "$DB_USER"
printf  "║  password: %-41s║\n" "$DB_PASS"
echo "║                                                      ║"
echo "║  psql rápido:                                        ║"
printf  "║  PGPASSWORD='%s'\n" "$DB_PASS"
printf  "║    psql -h localhost -U %s -d %s\n" "$DB_USER" "$DB_NAME"
echo "║                                                      ║"
echo "║  Ctrl+C para encerrar e remover o pod               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

kubectl port-forward "pod/$POD_NAME" \
  "$LOCAL_PORT":5432 \
  --namespace="$NAMESPACE"
