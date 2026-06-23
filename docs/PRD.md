# Product Requirements Document (PRD)
## Sequence — Cloud-Native Multiplayer Card Game

**Version:** 1.0  
**Date:** 2026-06-22  
**Author:** Anurag Raj  
**Status:** Approved

---

## 1. Product Vision

Build a cloud-native multiplayer card game (Sequence-inspired) that serves as a reference implementation of enterprise-grade DevOps, Platform Engineering, and SRE practices on Azure Kubernetes Service.

> The game is the business use case. The infrastructure, deployment pipelines, observability, and security are the real product.

---

## 2. Target Users

| User Type | Description | Primary Concern |
|---|---|---|
| Mobile Players | Users playing on iOS/Android | Low latency, real-time gameplay |
| Game Spectators | Users watching live games | Read-heavy, eventual consistency acceptable |
| Platform Engineers | Operating and evolving the platform | Observability, reliability, deployability |

---

## 3. Core Features

### Priority 0 — MVP (Week 1-4)

| Feature | Description | Services Involved |
|---|---|---|
| User Registration | Email + password signup | auth-service, PostgreSQL |
| User Login | JWT-based authentication | auth-service, Redis |
| Create Game Room | Host creates a game lobby | matchmaking-service |
| Join Game Room | Player joins existing lobby | matchmaking-service |
| Real-Time Gameplay | Live card placement via WebSocket | game-service, Redis |
| Game State Persistence | Board state survives disconnects | game-service, Redis |
| Win Detection | Sequence detection algorithm | game-service |

### Priority 1 — Enhanced (Week 5-8)

| Feature | Description | Services Involved |
|---|---|---|
| Player Leaderboard | Global ranking by wins | leaderboard-service |
| Push Notifications | Opponent's turn alerts | notification-service |
| Game History | View past games | analytics-service, PostgreSQL |
| Player Profile | Stats, win rate, game count | auth-service |

### Priority 2 — Future (Week 9+)

| Feature | Description | Services Involved |
|---|---|---|
| In-Game Chat | Real-time text chat | chat-service (new) |
| Spectator Mode | Watch ongoing games | game-service, WebSocket |
| Tournament Mode | Bracketed competitions | tournament-service (new) |
| Replay System | Game replay from event log | analytics-service |

---

## 4. Non-Functional Requirements

### Availability

| Service | SLO | Error Budget (28d) |
|---|---|---|
| auth-service | 99.9% | 40 minutes |
| game-service | 99.5% | 201 minutes |
| matchmaking-service | 99.0% | 403 minutes |
| leaderboard-service | 99.0% | 403 minutes |

### Performance

| Metric | Target | Measurement |
|---|---|---|
| Game move latency | p99 < 200ms | Istio + Prometheus |
| Auth latency | p99 < 100ms | Prometheus histogram |
| Matchmaking time | p95 < 5 seconds | Custom metric |
| WebSocket connection | < 500ms to establish | Client-side telemetry |
| Concurrent games | 1,000 simultaneous | Load test with k6 |
| Concurrent users | 5,000 | Load test with k6 |

### Security

| Requirement | Implementation |
|---|---|
| Authentication | JWT (RS256), 15-minute access token |
| Transport security | TLS 1.3 + Istio mTLS between services |
| Secret management | Azure Key Vault + CSI Driver |
| Image security | Trivy scan + Cosign signing in CI/CD |
| Admission control | Kyverno policies + OPA Gatekeeper |
| Zero-trust networking | Istio AuthorizationPolicy deny-all default |
| Supply chain | SBOM generation, SLSA Level 2 |

### Reliability

| Metric | Target |
|---|---|
| RTO (node failure) | < 5 minutes |
| RTO (AZ outage) | < 10 minutes |
| RPO (data loss) | < 5 minutes |
| MTTR | < 30 minutes |
| Deployment frequency | Multiple per day |

### Scalability

| Dimension | Mechanism |
|---|---|
| Horizontal pod scaling | HPA on CPU/memory |
| Event-driven scaling | KEDA on queue depth / WebSocket connections |
| Node scaling | Cluster Autoscaler |
| Database scaling | Read replicas for leaderboard queries |

---

## 5. Technology Constraints

- **Cloud:** Azure only (demonstrates Azure-specific expertise)
- **Kubernetes:** AKS (managed control plane)
- **Language:** Go for all services (low memory, WebSocket support, K8s native)
- **IaC:** Terraform (not Bicep — cloud-agnostic skill)
- **GitOps:** ArgoCD (not Flux — richer UI, wider adoption)
- **Service Mesh:** Istio (not Linkerd — more concepts, higher interview value)

---

## 6. Out of Scope

- Mobile client implementation (stub/mock clients sufficient for demo)
- Payment processing
- Regulatory compliance (GDPR, PCI-DSS) — acknowledged but not implemented
- Multi-region active-active (DR plan covers single-region failure only)
