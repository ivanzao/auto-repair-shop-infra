# ADR-003 — S3 storage viable in AWS Academy via IMDS hop_limit + LabRole

## Status

Accepted — 2026-05-18
Supersedes the "storage" section of ADR-001.

## Context

ADR-001 concluded that S3-backed observability storage was infeasible in
AWS Academy because IRSA is blocked. The reasoning: without IRSA, the only
way to give pods AWS credentials would be to bake static creds into helm
values (no workload isolation, secret rotation pain).

On 2026-05-17 I tested whether pods could inherit `LabRole` via the EC2
Instance Metadata Service (IMDS). Result:

- **CLI as `voclabs`:** can create/read/write S3 buckets.
- **Pod with `hostNetwork: true`:** `aws sts get-caller-identity` returns
  `assumed-role/LabRole/i-...`; can create S3 buckets.
- **Pod without `hostNetwork`:** IMDS unreachable (token request returns empty).

The blocker for normal pods is the EKS launch-template default
`HttpPutResponseHopLimit=1`. With one hop, the IMDS packet dies on the
CNI bridge before reaching the host's `169.254.169.254`. Setting hop_limit=2
fixes this — every pod can hit IMDS and inherit LabRole automatically.

Tested permissions: LabRole's `VocLabPolicy*` set includes S3 read/write
(confirmed by creating, putting, getting, and deleting a bucket from inside
a host-network pod).

## Decision

For **storage** of observability data, use S3 (per signal):
- Loki chunks → `<prefix>-loki-<account>`
- Tempo blocks → `<prefix>-tempo-<account>`
- Mimir blocks/alerts/rules → `<prefix>-mimir-<account>`

Bind mechanism:
- `modules/eks/main.tf` defines `aws_launch_template` with
  `metadata_options.http_put_response_hop_limit = 2`.
- `aws_eks_node_group.default` references the launch template.
- Pods inherit LabRole via IMDS — no SA annotation, no IRSA, no Pod Identity.

Bucket lifecycle policies (7/3/14 days hml, 30/14/90 days prod) keep storage
costs negligible.

## Consequences

**Positive:**
- Logs, traces, and metrics survive pod restarts.
- No data loss on `terraform destroy` of the cluster (buckets persist).
- Same code path runs on any cluster that has the launch template change.

**Negative:**
- **All pods on the node share `LabRole` credentials.** Workload-scoped
  identity (IRSA / Pod Identity) is gone. In a multi-tenant cluster this
  would be a hard NO. Acceptable in the lab where the cluster is single-tenant.
- The hop_limit change requires recreating the node group (EKS managed
  node groups can't update metadata options in place).

## Alternatives considered

1. **EKS Pod Identity.** Requires creating a role with `pods.eks.amazonaws.com`
   in the trust policy. `iam:CreateRole` and `iam:UpdateAssumeRolePolicy` are
   denied for `voclabs` (confirmed by test). Cannot use.

2. **IRSA.** Requires `iam:CreateOpenIDConnectProvider`, denied for `voclabs`
   (per ADR-001 and `project-aws-academy-iam-limits` memory). Cannot use.

3. **Static credentials in helm values.** Possible but creates a rotation
   problem (Academy creds expire every few hours) and exposes a secret in
   the helm values file. Rejected.

4. **Keep emptyDir (ADR-001 original).** Works but loses data on every pod
   restart. The IMDS finding makes this unnecessary.

## How to do this properly outside the lab

- Use IRSA (or EKS Pod Identity) so each workload's ServiceAccount maps to
  a dedicated IAM role with least-privilege S3 access.
- Restore `HttpPutResponseHopLimit=1` (the EKS default) so non-IRSA pods
  can't reach IMDS at all.

## Related

- ADR-001 — AWS Academy storage constraints (superseded for storage section).
- Memory: `project-aws-academy-iam-limits`.
