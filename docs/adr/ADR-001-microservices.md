# ADR-001: Microservices over Monolith

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

The Sequence game could be built as a single monolithic application. All features (auth, game logic, matchmaking, leaderboard, notifications, analytics) could live in one process and one codebase.

The primary goal of this project is demonstrating DevOps and Kubernetes skills, not building the simplest possible application.

## Decision

Use microservices architecture with 6 independently deployable services.

## Rationale

| Goal | Monolith | Microservices |
|---|---|---|
| Independent scaling | Not possible | Yes — game-service scales separately from auth-service |
| Istio mTLS demo | Nothing to show | Real mTLS between services |
| Per-service HPA/KEDA | Nothing to show | Each service has its own scaling policy |
| ArgoCD ApplicationSets | One app | 6 apps across 3 environments |
| Distributed tracing (Tempo) | No distributed calls | Real trace spans across services |
| Independent deployments | Risky, all-or-nothing | Deploy leaderboard fix without touching game logic |

## Consequences

**Positive:**
- Demonstrates Kubernetes at production scale
- Enables Istio service mesh features (mTLS, canary, circuit breaking)
- Enables KEDA scaling per service based on relevant metrics
- Enables ArgoCD multi-app GitOps management
- Requires distributed tracing (Tempo/Jaeger) — hands-on observability

**Negative:**
- Higher operational complexity
- Network latency between services (mitigated by Istio + co-location in same cluster)
- Requires service discovery, load balancing, circuit breaking
- More infrastructure to manage and monitor

## Alternatives Considered

**Modular Monolith:** Single deployable unit with clean internal module boundaries. Rejected because it cannot demonstrate Istio inter-service mTLS, independent HPA per service, or ArgoCD ApplicationSet management across multiple services.

**Three-Tier Architecture:** Rejected — does not demonstrate Kubernetes expertise beyond basic pod deployment.

## Interview Guidance

When asked "Why microservices?", say:
> "I chose microservices specifically because the project goal is demonstrating production DevOps practices. Microservices forced me to solve real distributed systems problems: service discovery, distributed tracing, mTLS between services, and per-service autoscaling. A monolith would have reduced these to theoretical exercises."
