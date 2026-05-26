# ADR-006 — Observability Stack: Ordem de Bootstrap e wait=false

**Status:** Accepted
**Data:** 2026-05-26

## Contexto

O stack de observabilidade tem dependências de bootstrap não-óbvias que exigem
`wait = false` e `depends_on` específicos entre charts sem relação aparente.

## Decisões

### 1. OTel Operator depende do ALB Controller

O ALB Controller instala um `MutatingWebhookConfiguration` que intercepta criações
de Services. O OTel Operator também cria Services durante o install. Se o webhook
do ALB Controller não estiver pronto quando o OTel Operator instala, o webhook
intercepta a criação do Service do OTel e falha o install do chart.

```hcl
resource "helm_release" "otel_operator" {
  depends_on = [
    kubernetes_namespace.observability,
    helm_release.alb_controller,
  ]
}
```

### 2. kube-prometheus-stack: wait = false

O Grafana persiste estado no banco `grafana_<env>` no RDS, cujo role e database
são criados pelo `kubernetes_job_v1.db_init`. No bootstrap o Terraform aplica o
chart na fase 1, antes do Job de init da fase 2 existir, então o Grafana inicia
em CrashLoop por falta do banco.

`wait = false` permite que o Terraform marque o release como deployed mesmo com
pods não-prontos. O Grafana auto-recupera quando o Job de init cria o banco.

### 3. Loki e Tempo: wait = false

No primeiro deploy, o resource budget dos nós é apertado (2× t3.medium dividindo
Prometheus, Grafana, Loki, Tempo e Alloy). `wait = false` evita timeout do
`terraform apply` enquanto pods aguardam scheduling.

## Consequências

- Um `terraform apply` limpo pode completar com Grafana e Loki/Tempo ainda
  inicializando. Isso é esperado — convergem sozinhos em poucos minutos.
- Monitorar com: `kubectl get pods -n observability -w`
