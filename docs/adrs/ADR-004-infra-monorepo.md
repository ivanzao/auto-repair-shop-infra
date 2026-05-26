# ADR-005 — K8s e BD no mesmo repositório de infra

**Status:** Aceito — 2026-05-25

## Contexto

O enunciado sugere 4 repositórios: Lambda, Infra K8s, Infra BD e Aplicação. O AWS Academy disponibiliza apenas `LabRole` — sem criação de roles IAM dedicadas por sub-projeto. Separar K8s e BD em repos distintos não traz isolamento real de credenciais e cria acoplamento frágil de bootstrap entre pipelines Terraform independentes.

## Decisão

Infraestrutura K8s e BD consolidados em `auto-repair-shop-infra`, com módulos Terraform separados logicamente. Blast radius mitigado por ambiente (`hml/` vs `prod/`) em vez de por camada.

| Exigido pelo enunciado | Entregue |
|------------------------|----------|
| Lambda | ✅ `auto-repair-shop-lambdas` |
| K8s Infra (Terraform) | ⚠️ consolidado em `auto-repair-shop-infra` |
| BD Infra (Terraform) | ⚠️ consolidado em `auto-repair-shop-infra` |
| Aplicação | ✅ `auto-repair-shop` |

## Consequências

- Bootstrap de um ambiente novo é um único `terraform apply` — sem acoplamento entre pipelines
- Mudanças cross-camada (ex: novo security group no RDS + ajuste no EKS) ficam em 1 PR
- Desvio formal do enunciado — risco de desconto de nota, mitigado por esta ADR
- Refactor para 4 repos é viável quando houver conta AWS com IAM real (fora do Academy)
