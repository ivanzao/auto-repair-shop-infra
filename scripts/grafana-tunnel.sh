#!/usr/bin/env bash
# grafana-tunnel.sh — abre port-forward para o Grafana do cluster EKS
#
# Uso:
#   ./scripts/grafana-tunnel.sh [prod|hml]
#
# Resultado:
#   Grafana acessível em http://localhost:3000
#   Ctrl+C para encerrar.
#
# Pré-requisitos: aws cli, kubectl
# Credenciais AWS resolvidas pela cadeia padrão do CLI (aws configure / ~/.aws/credentials / env vars)

set -euo pipefail

ENV="${1:-prod}"

if [[ "$ENV" != "prod" && "$ENV" != "hml" ]]; then
  echo "uso: $0 [prod|hml]" >&2
  exit 1
fi

LOCAL_PORT=3000

CLUSTER_NAME=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/eks/cluster-name" \
  --query Parameter.Value --output text)

echo "→ atualizando kubeconfig para $CLUSTER_NAME..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "${AWS_DEFAULT_REGION:-us-east-1}" 2>/dev/null

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Grafana disponível em:                             ║"
echo "║  http://localhost:3000                              ║"
echo "║  login: admin / admin                              ║"
echo "║                                                      ║"
echo "║  Ctrl+C para encerrar                               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

kubectl port-forward \
  -n observability \
  svc/kube-prometheus-stack-grafana \
  "$LOCAL_PORT":80
