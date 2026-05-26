# ADR-005 — AWS Academy IAM Constraints e Workarounds

**Status:** Accepted
**Data:** 2026-05-26

## Contexto

O ambiente AWS Academy usa `LabRole` + `VocLabPolicy*` com explicit denies em:
- `iam:CreatePolicy`
- `iam:AttachRolePolicy`
- `iam:CreateRole` (limitado)
- `iam:PassRole` (limitado a LabRole)

Isso impede os padrões normais de IRSA (IAM Roles for Service Accounts), onde o
Terraform criaria uma role dedicada por workload e a vincularia via annotation.

## Decisões

### 1. IMDS hop limit = 2 no Launch Template dos nós EKS

Por padrão o EKS configura `http_put_response_hop_limit = 1`, o que impede pods de
alcançar o IMDS em `169.254.169.254`. Com hop limit = 2, os pods conseguem fazer a
chamada IMDS e herdar as credenciais da node IAM role (LabRole + VocLabPolicy*).

```hcl
metadata_options {
  http_put_response_hop_limit = 2
}
```

### 2. AWS Load Balancer Controller sem política dedicada

O controller normalmente exige uma IAM policy específica criada e vinculada à role
do Service Account. No Academy, `iam:AttachRolePolicy` é negado. O controller herda
as permissões de EC2/ELB da LabRole via IMDS (hop limit = 2).

### 3. App Service Account e SNS Publish

O pod da aplicação precisa de `sns:Publish`. No Academy não é possível criar uma
role dedicada com essa permissão. Solução idêntica: IMDS com hop limit = 2 →
credenciais da LabRole → VocLabPolicy* que inclui ações SNS.

## Consequências

- Todos os workloads que precisam de AWS APIs herdam credenciais via IMDS, não via
  IRSA Web Identity Token. Suficiente para o contexto acadêmico.
- Em produção real: substituir por IRSA com roles dedicadas por workload.
- Ver ADR-003 para o detalhamento do IMDS hop limit no contexto de acesso ao S3.
