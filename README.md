# Sequence — Cloud-Native DevOps Portfolio Project

> A multiplayer card game built on Azure Kubernetes Service as a reference implementation of enterprise-grade DevOps, Platform Engineering, and SRE practices.

[![CI - Auth Service](https://github.com/Callmeanurag/Sequence/actions/workflows/ci-auth-service.yml/badge.svg)](https://github.com/Callmeanurag/Sequence/actions/workflows/ci-auth-service.yml)
[![CI - Game Service](https://github.com/Callmeanurag/Sequence/actions/workflows/ci-game-service.yml/badge.svg)](https://github.com/Callmeanurag/Sequence/actions/workflows/ci-game-service.yml)
[![Security Scan](https://github.com/Callmeanurag/Sequence/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Callmeanurag/Sequence/actions/workflows/security-scan.yml)

---

## What This Project Demonstrates

The game is the business use case. The real goal is demonstrating production-grade DevOps engineering across the full platform stack.

| Domain | Technologies |
|---|---|
| Cloud | Azure AKS, ACR, Key Vault, PostgreSQL, Redis, Azure Monitor |
| Kubernetes | Multi-node pools, RBAC, HPA, VPA, KEDA, Cluster Autoscaler |
| Service Mesh | Istio — mTLS, canary deployments, circuit breaking, fault injection |
| GitOps | ArgoCD, ApplicationSets, App-of-Apps, drift detection |
| IaC | Terraform — modules, remote state, environment strategy |
| Observability | Prometheus, Grafana, Loki, Tempo (full LGTM stack) |
| Security | Trivy, Cosign, Kyverno, OPA Gatekeeper, Workload Identity |
| SRE | SLO/error budgets, alerting, runbooks, incident management |
| CI/CD | GitHub Actions — build, scan, sign, deploy pipeline |

---

## Architecture

**Pattern:** Hybrid Microservices + Event-Driven Architecture

```
Mobile Clients
      │
      ▼
Istio Ingress Gateway
      │  (mTLS between all services)
      ▼
┌─────────────────────────────────────────────┐
│              SERVICE MESH (Istio)            │
│                                             │
│  auth-service      game-service             │
│  matchmaking-svc   leaderboard-svc          │
│  notification-svc  analytics-svc            │
└─────────────────────────────────────────────┘
      │                    │
      ▼                    ▼
PostgreSQL             Redis Cache
(game history,         (active game state,
 user accounts)         sessions, pub/sub)
```

See [docs/HLD.md](docs/HLD.md) for full architecture diagrams.

---

## Repository Structure

```
.
├── docs/                        # All architecture documentation
│   ├── PRD.md                   # Product Requirements Document
│   ├── HLD.md                   # High Level Design
│   ├── LLD.md                   # Low Level Design
│   ├── ARCHITECTURE.md          # Cloud + AKS + Istio architecture
│   ├── COST-ANALYSIS.md         # Azure cost breakdown
│   ├── adr/                     # Architecture Decision Records
│   ├── runbooks/                # SRE operational runbooks
│   └── sre/                     # SLO definitions + error budget policy
│
├── infrastructure/              # Terraform IaC
│   ├── modules/                 # Reusable Terraform modules
│   │   ├── aks/                 # AKS cluster module
│   │   ├── networking/          # VNet, subnets, NSG
│   │   ├── acr/                 # Azure Container Registry
│   │   ├── postgresql/          # PostgreSQL Flexible Server
│   │   ├── redis/               # Azure Cache for Redis
│   │   └── keyvault/            # Azure Key Vault
│   └── environments/            # Per-environment configurations
│       ├── dev/
│       ├── staging/
│       └── prod/
│
├── services/                    # Microservices source code
│   ├── auth-service/
│   ├── game-service/
│   ├── matchmaking-service/
│   ├── leaderboard-service/
│   ├── notification-service/
│   └── analytics-service/
│
├── kubernetes/                  # Kubernetes manifests (Kustomize)
│   ├── base/                    # Base manifests per service
│   ├── overlays/                # Environment-specific overlays
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── platform/                # Istio, cert-manager configs
│
├── gitops/                      # ArgoCD manifests
│   ├── bootstrap/               # Cluster bootstrap (App-of-Apps)
│   ├── applications/            # Per-service ArgoCD Applications
│   └── applicationsets/         # Multi-env ApplicationSets
│
├── observability/               # Monitoring stack configuration
│   ├── prometheus/              # Prometheus values + alert rules
│   ├── grafana/                 # Grafana dashboards
│   ├── loki/                    # Log aggregation
│   └── tempo/                   # Distributed tracing
│
├── security/                    # Security policies
│   ├── kyverno/                 # Admission control policies
│   ├── istio/                   # PeerAuthentication + AuthorizationPolicies
│   └── opa/                     # OPA Gatekeeper constraints
│
├── .github/workflows/           # GitHub Actions CI/CD pipelines
└── scripts/                     # Bootstrap and operational scripts
```

---

## Getting Started

### Prerequisites

- Azure CLI (`az`) — authenticated
- Terraform >= 1.7
- kubectl >= 1.28
- Helm >= 3.12
- ArgoCD CLI
- istioctl

### 1. Provision Infrastructure

```bash
cd infrastructure/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 2. Bootstrap the Cluster

```bash
./scripts/bootstrap-cluster.sh dev
```

### 3. Install ArgoCD

```bash
./scripts/install-argocd.sh
```

### 4. Deploy App-of-Apps

```bash
kubectl apply -f gitops/bootstrap/root-app.yaml
```

ArgoCD will reconcile all services automatically.

---

## ADR Index

| ADR | Decision | Status |
|---|---|---|
| [ADR-001](docs/adr/ADR-001-microservices.md) | Microservices over Monolith | Accepted |
| [ADR-002](docs/adr/ADR-002-aks.md) | AKS over Self-Managed Kubernetes | Accepted |
| [ADR-003](docs/adr/ADR-003-argocd.md) | ArgoCD over Flux for GitOps | Accepted |
| [ADR-004](docs/adr/ADR-004-istio.md) | Istio Service Mesh | Accepted |
| [ADR-005](docs/adr/ADR-005-terraform.md) | Terraform over Bicep/Pulumi | Accepted |
| [ADR-006](docs/adr/ADR-006-postgresql.md) | PostgreSQL Flexible Server | Accepted |
| [ADR-007](docs/adr/ADR-007-redis.md) | Redis for Game State | Accepted |

---

## SLO Summary

| Service | Availability SLO | Latency SLO (p99) |
|---|---|---|
| auth-service | 99.9% | < 100ms |
| game-service | 99.5% | < 200ms |
| matchmaking-service | 99.0% | < 1000ms |
| leaderboard-service | 99.0% | < 500ms |

See [docs/sre/SLO-definitions.md](docs/sre/SLO-definitions.md) for full definitions and error budget policy.

---

## Author

**Anurag Raj** — DevOps & Platform Engineering Portfolio  
GitHub: [@Callmeanurag](https://github.com/Callmeanurag)
