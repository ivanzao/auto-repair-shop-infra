#!/usr/bin/env bash
# grafana-tunnel.sh: abre port-forward para o Grafana do cluster EKS
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

ADMIN_PASS=$(kubectl get secret -n observability kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "(veja o secret kube-prometheus-stack-grafana)")

cat <<EOF

╔═══════════════════════════════════════════════════════════════════
║  Grafana ($ENV) em http://localhost:$LOCAL_PORT
║  login: admin / $ADMIN_PASS
╠═══════════════════════════════════════════════════════════════════
║  Pasta "Auto Repair Shop":
║
║    Orders Operations      /d/auto-repair-orders-ops
║      status da OS ao longo do fluxo (painel principal)
║    Execution Saga         /d/auto-repair-execution-saga
║      fila da oficina, reservas, insumo indisponível
║    APM por serviço        /d/auto-repair-apm
║    Errors & Integrations  /d/auto-repair-errors
║
║  Explore (query ad-hoc): /explore
║    orders_by_status_total{status="WAITING_APPROVAL"}
║    execution_by_status_total{status="AWAITING_DIAGNOSIS"}
║    execution_supplies_reserved_total
║    execution_supplies_unavailable_total
║
║  Ctrl+C para encerrar
╚═══════════════════════════════════════════════════════════════════

EOF

kubectl port-forward \
  -n observability \
  svc/kube-prometheus-stack-grafana \
  "$LOCAL_PORT":80
