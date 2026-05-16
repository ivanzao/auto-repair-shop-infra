# ADR-002 — Hardcoded credentials acceptable for academic project

## Status

Accepted — 2026-05-18

## Context

The observability stack needs credentials for two consumers:

1. **Grafana admin UI** — `adminPassword` in the kube-prometheus-stack chart.
2. **Grafana database backend** — Postgres role on the shared RDS for state
   persistence.

The market-standard pattern is External Secrets Operator + AWS Secrets Manager
(or Sealed Secrets, or random_password + kubernetes_secret). All of these
add infrastructure components and require operator workflows for rotation
and recovery.

This repository backs a post-graduation project. There are no real users,
no compliance requirements, and the cluster is regularly destroyed and
recreated. The cost of secret-management infrastructure outweighs the benefit.

## Decision

Both passwords default to `"admin"`, hardcoded as Terraform variable defaults
(`var.grafana_admin_password`, `var.grafana_db_password`) and interpolated into
helm values via `templatefile()`.

The strings do **not** appear in any committed YAML or HCL — they live only
in variable defaults. A reviewer can scan the repo for the literal `"admin"`
to find every occurrence.

## Consequences

**Positive:**
- Zero secret-management infrastructure.
- One-line credential recovery (`terraform output -raw` or remembering "admin").
- Onboarding a teammate is trivial.

**Negative:**
- Cannot be deployed to any environment with real users without first removing
  the defaults and wiring proper secret storage.
- A future maintainer might forget the trade-off and treat this stack as
  production-ready.

## Related lab-context decisions

This ADR also covers a related "lab-friendly" choice in `prod/main.tf`:

- **`skip_final_snapshot = true` on the prod RDS** — the production safety
  default is `false` (force a final snapshot before destroy). In a real prod
  that's the right default: it prevents accidental data loss when someone
  fat-fingers `terraform destroy`. In this lab the cluster is destroyed and
  recreated on every iteration, the snapshot guardrail is pure friction, and
  there is no production data worth keeping. Both envs are set to `true`.

## How to do this properly outside the lab

1. Drop the defaults from `var.grafana_admin_password` and `var.grafana_db_password`.
2. Generate values via `random_password` or read from AWS Secrets Manager.
3. Pass via `tfvars` from a CI secret, never committed.
4. For ESO: install the operator, create a `ClusterSecretStore` pointing at
   AWS Secrets Manager, declare `ExternalSecret` resources for Grafana.
5. Flip `prod/main.tf` `skip_final_snapshot` back to `false` (and add a
   `final_snapshot_identifier` strategy in the destroy workflow if you ever
   need to wind down prod intentionally).

## Related

- ADR-001 — AWS Academy storage constraints (originator of the "good enough
  for the lab" mindset).
- ADR-003 — S3 via IMDS hop_limit (similar academic-context decision).
