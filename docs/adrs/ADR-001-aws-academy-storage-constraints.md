# ADR-001 — AWS Academy storage constraints: ephemeral observability volumes

## Status

Accepted — 2026-05-17

## Context

The infra deploys to an **AWS Academy** sandbox (assumed-role `voclabs`,
`LabRole` as the only IAM role). Several stateful components in the observability
stack (Loki, Tempo, Prometheus, MinIO) want `PersistentVolumeClaim` storage backed
by EBS via `gp2`/`gp3`.

Two constraints surface as blockers:

1. **EBS CSI driver is not installed and we cannot install it as an
   EKS-managed addon under IRSA.** AWS Academy explicitly denies the IAM
   actions required to wire up IRSA (`iam:CreateOpenIDConnectProvider`,
   `iam:AttachRolePolicy` on `LabRole`, `iam:TagPolicy`). See the broader
   list in commit history and `MEMORY.md`. Without IRSA, the addon falls back
   to node IAM, which has worked for some workloads (cloud-controller-manager
   LB provisioning) but is unreliable for the EBS CSI controller — and any
   failure during provisioning leaves PVCs `Pending` indefinitely.

2. **Node IP/pod density is tight.** A single `t3.medium` node ships with a
   `pods` capacity of 17 (driven by VPC CNI ENI IP limits). The base
   observability stack already pushes close to that ceiling; adding a MinIO
   StatefulSet (`loki-minio`) plus its sidecar canary pushes us over and
   leaves new pods in `FailedScheduling: Too many pods`.

We hit both at once when configuring Loki: we tried filesystem-backed
storage with `singleBinary.persistence.enabled: true` (which defaults to a
PVC) and then MinIO-backed storage (`loki.storage.type: s3` +
`minio.enabled: true`). Both failed for the same root reason — there is no
working dynamic volume provisioner in the cluster, and even if there were,
the MinIO pod cannot be scheduled.

## Decision

> **Update 2026-05-18:** The storage portion of this ADR is superseded by
> ADR-003. New finding: pods can inherit `LabRole` via IMDS when the node
> launch template raises `HttpPutResponseHopLimit` to 2 — enabling S3-backed
> Loki/Tempo/Mimir without IRSA. The IAM-restrictions context below remains
> accurate.

For the lab/Academy environment, **stateful observability components use
ephemeral `emptyDir` volumes** rather than PVCs. Specifically:

- **Loki SingleBinary**: `persistence.enabled: false` and explicit
  `extraVolumes`/`extraVolumeMounts` mapping an `emptyDir` to `/var/loki`.
  (The chart does **not** auto-fall-back to `emptyDir` when persistence is
  disabled — without these extras it tries to write to the read-only
  container root, which crash-loops the pod.)
- **MinIO**: disabled. Loki uses local filesystem storage.
- **`loki-canary`**: disabled. It is a debugging DaemonSet and not worth
  the pod slot in a 17-pod node budget.

Future stateful components (Tempo, etc.) follow the same rule: prefer
`emptyDir`, document the data-loss trade-off, and revisit only if/when
the lab gets a working CSI driver or moves off Academy.

## Consequences

**Trade-off accepted:** log data does not survive pod restarts, node
replacements, or `terraform destroy`. This is acceptable for the lab — the
whole cluster is recreated frequently and logs are only meaningful for
short-lived debugging sessions.

**Positive:**
- Removes hard dependency on EBS CSI driver (which we cannot install
  cleanly without IRSA).
- Frees pod slots and EBS volume budget — keeps us within Academy limits.
- Same code path runs on any cluster (no provider-specific PV assumptions).

**Negative:**
- No log retention across pod lifecycle. Pod restart → empty Loki.
- `terraform destroy` is harder if/when we change our mind, because state
  must be re-created instead of re-attached.
- Diverges from the production-grade pattern (MinIO bundled or S3 backend),
  so we maintain a separate config path for non-Academy environments.

## Alternatives considered

1. **Install `aws-ebs-csi-driver` via EKS addon with node-IAM auth.**
   Rejected: the addon's controller requires IAM permissions to create EBS
   volumes; without IRSA we have to rely on the node IAM (LabRole). LabRole
   has broad EC2 permissions but the addon's webhook expects a dedicated
   ServiceAccount-scoped role, and provisioning silently fails in
   `WaitForFirstConsumer` mode. Time-to-debug is high in a lab where the
   environment is torn down every few hours.

2. **MinIO bundled (`minio.enabled: true`) with `gp2` StorageClass.**
   Rejected for two reasons: (a) still needs working EBS CSI (same problem
   as above); (b) the MinIO `StatefulSet` adds 1+ pods on top of an already
   maxed-out node, putting us over the pod density ceiling without scaling
   the node group.

3. **Scale the node group up (`node_desired_size: 1 → 2/3`) and/or upgrade
   instance type (`t3.medium → t3.large`).**
   Worth doing eventually for headroom, but doesn't solve the underlying
   CSI/IRSA problem. Tracked separately — out of scope for this ADR.

4. **External S3 bucket (real AWS S3, not MinIO).** Would work and is the
   "right" answer for non-Academy. Rejected here because the only IAM
   identity available is `LabRole`, shared across all workloads — losing
   the workload-scoped boundary that IRSA would provide, and we did not
   want to bake S3 credentials into the helm values.

## Related

- [project-aws-academy-iam-limits](../../.. — memory: detailed list of
  IAM denies that drove most of these constraints)
- [project-loki-config](../../.. — memory: Loki SingleBinary defaults and
  template behavior)
