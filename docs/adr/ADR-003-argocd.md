# ADR-003: ArgoCD over Flux for GitOps

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

GitOps requires a reconciliation controller that continuously syncs desired state from Git to the cluster. The two dominant options are ArgoCD and Flux (both CNCF graduated projects).

## Decision

Use ArgoCD with App-of-Apps pattern and ApplicationSets.

## Rationale

| Dimension | ArgoCD | Flux |
|---|---|---|
| UI | Rich web UI with drift visualization | Minimal UI (Weave GitOps adds UI separately) |
| Multi-environment | ApplicationSets (built-in) | Kustomize controllers |
| Bootstrap | App-of-Apps pattern well-documented | Flux bootstrap CLI |
| Industry adoption | Very wide (most interview questions reference ArgoCD) | Growing but smaller base |
| Operational footprint | Slightly heavier | Lightweight |
| CNCF status | Graduated | Graduated |

## Implementation

**App-of-Apps Pattern:**
```
gitops/bootstrap/root-app.yaml
  ↓ (ArgoCD Application)
  Deploys all Applications in gitops/applications/
  Each Application points to kubernetes/overlays/{env}/{service}/
  Kustomize builds the final manifests
```

**ApplicationSet for multi-environment:**
```yaml
# Single ApplicationSet generates one Application per (environment, service) combo
# 3 environments × 6 services = 18 Applications created automatically
```

## Consequences

**Positive:**
- Declarative, self-healing — ArgoCD continuously reconciles drift
- Rich UI shows sync status, resource health, diff view
- ApplicationSets eliminate repetitive Application YAML
- Rollback is `argocd app rollback <app> <revision>` — Git history is the rollback mechanism
- Webhook support reduces reconciliation latency from ~3min to ~10s

**Negative:**
- ArgoCD itself is a workload that must be managed (dedicated namespace, RBAC)
- Requires understanding of Application, AppProject, and Repository CRDs
- Secret management for Git credentials requires sealed-secrets or external-secrets

## Alternatives Considered

**Flux:** Technically equivalent capabilities. Rejected primarily because ArgoCD's UI makes drift detection immediately visible and demonstrable in interviews and LinkedIn demos. The visual diff view in ArgoCD is worth the slightly higher operational overhead for a portfolio project.

## Interview Guidance

**Question:** "How does ArgoCD detect drift and what happens when it finds it?"

Answer: "ArgoCD runs a reconciliation loop every 3 minutes (configurable) or responds to webhooks immediately. It compares the live cluster state — obtained via Kubernetes API — with the desired state computed from the Git repository (running Helm or Kustomize locally). If it detects a difference, it marks the application as OutOfSync. Depending on the sync policy (manual vs automated), it either waits for a human to approve sync, or automatically applies the diff using server-side apply. If the apply fails — for example, a bad manifest — it marks the application as Degraded. I have alerts on Degraded applications that page the on-call engineer."
