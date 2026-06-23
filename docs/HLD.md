# High Level Design (HLD)
## Sequence — Cloud-Native Platform

**Version:** 1.0  
**Date:** 2026-06-22

---

## 1. Architecture Overview

**Pattern:** Hybrid Microservices + Event-Driven Architecture

The system uses synchronous communication (REST/gRPC/WebSocket) for operations requiring immediate responses, and asynchronous event-driven communication (NATS/Azure Service Bus) for operations that can be processed eventually.

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AZURE CLOUD                               │
│                                                                     │
│  ┌─────────┐    ┌──────────────────────────────────────────────┐   │
│  │  Azure  │    │             AKS CLUSTER                      │   │
│  │  CDN /  │    │  ┌────────────────────────────────────────┐  │   │
│  │  APIM   │───▶│  │       ISTIO INGRESS GATEWAY            │  │   │
│  └─────────┘    │  └────────────────┬───────────────────────┘  │   │
│                 │                   │ (mTLS enforced)           │   │
│  ┌─────────┐    │  ┌────────────────▼───────────────────────┐  │   │
│  │ Mobile  │───▶│  │           SERVICE MESH                  │  │   │
│  │ Clients │    │  │                                         │  │   │
│  └─────────┘    │  │  ┌──────────┐  ┌──────────────────┐   │  │   │
│                 │  │  │   auth   │  │      game        │   │  │   │
│                 │  │  │ service  │  │     service      │   │  │   │
│                 │  │  └──────────┘  └──────────────────┘   │  │   │
│                 │  │  ┌──────────┐  ┌──────────────────┐   │  │   │
│                 │  │  │matchmkng │  │   leaderboard    │   │  │   │
│                 │  │  │ service  │  │     service      │   │  │   │
│                 │  │  └──────────┘  └──────────────────┘   │  │   │
│                 │  │  ┌──────────┐  ┌──────────────────┐   │  │   │
│                 │  │  │  notif.  │  │   analytics      │   │  │   │
│                 │  │  │ service  │  │    service       │   │  │   │
│                 │  │  └──────────┘  └──────────────────┘   │  │   │
│                 │  │                    │                    │  │   │
│                 │  │  ┌─────────────────▼──────────────┐   │  │   │
│                 │  │  │         EVENT BUS (NATS)        │   │  │   │
│                 │  │  └────────────────────────────────┘   │  │   │
│                 │  └────────────────────────────────────────┘  │   │
│                 │                                               │   │
│                 │  ┌────────────────────────────────────────┐  │   │
│                 │  │         PLATFORM SERVICES              │  │   │
│                 │  │  ArgoCD │ Prometheus │ Grafana │ Loki  │  │   │
│                 │  │  Tempo  │ Kyverno   │ Tempo   │ KEDA  │  │   │
│                 │  └────────────────────────────────────────┘  │   │
│                 └───────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                  AZURE MANAGED SERVICES                      │  │
│  │  ACR    │ Key Vault │ PostgreSQL Flexible │ Redis Premium    │  │
│  │  Monitor│ App Insights │ Service Bus      │ Private DNS      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        CI/CD PIPELINE                               │
│                                                                     │
│  GitHub Push ──▶ GitHub Actions                                     │
│                      │                                              │
│                      ├── Build Docker Image                         │
│                      ├── Generate SBOM (Syft)                       │
│                      ├── Trivy Security Scan                        │
│                      ├── Push to ACR                                │
│                      ├── Sign Image (Cosign / keyless)              │
│                      └── Update image tag in GitOps repo            │
│                                 │                                   │
│                      ArgoCD detects change ──▶ Deploy to AKS        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Service Communication Map

```
                     ┌──────────────┐
                     │    Mobile    │
                     │    Client    │
                     └──────┬───────┘
                            │ HTTPS/WSS
                            ▼
                  ┌─────────────────┐
                  │  Istio Ingress  │
                  │    Gateway      │
                  └────────┬────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
   ┌────────────┐  ┌──────────────┐  ┌───────────────┐
   │    auth    │  │     game     │  │  matchmaking  │
   │  service   │  │   service    │  │    service    │
   └────────────┘  └──────┬───────┘  └───────────────┘
          │               │
          ▼               ├──── Redis (game state)
   ┌────────────┐         ├──── PostgreSQL (history)
   │ PostgreSQL │         └──── NATS (events)
   │   (users) │                    │
   └────────────┘         ┌─────────┼──────────────┐
                          ▼         ▼               ▼
                  ┌──────────┐ ┌──────────┐  ┌──────────┐
                  │leaderboard│ │  notif.  │  │analytics │
                  │  service  │ │  service │  │  service │
                  └──────────┘ └──────────┘  └──────────┘
```

---

## 3. Data Flow: Player Makes a Game Move

```
Step 1: Client sends move via WebSocket
        Mobile App ──[WSS]──▶ Istio Gateway ──[mTLS]──▶ game-service

Step 2: Validate move
        game-service reads board state from Redis
        game-service validates move against game rules

Step 3: Persist state (hot path — synchronous)
        game-service ──▶ Redis MULTI/EXEC (atomic update, < 1ms)

Step 4: Persist history (async)
        game-service ──▶ PostgreSQL (background goroutine)

Step 5: Broadcast result
        game-service ──[WS]──▶ Both players (< 50ms total)

Step 6: Publish event (async)
        game-service ──▶ NATS "game.move.made" event

Step 7: Event consumers process asynchronously
        leaderboard-service: if game over, update rankings
        notification-service: notify opponent of their turn
        analytics-service: record move for analytics
```

---

## 4. Data Flow: User Authentication

```
Step 1: POST /api/v1/auth/login
        Client ──▶ Istio Gateway ──▶ auth-service

Step 2: Validate credentials
        auth-service ──▶ PostgreSQL (lookup user by email)
        auth-service: bcrypt.CompareHashAndPassword()

Step 3: Issue tokens
        auth-service: generate JWT (RS256, 15min, private key from Key Vault)
        auth-service: generate refresh token (random bytes, store in Redis TTL 7d)

Step 4: Return tokens
        auth-service ──▶ Client: {accessToken, refreshToken}

Step 5: Subsequent requests
        Client sends Authorization: Bearer <accessToken>
        Istio validates JWT via RequestAuthentication policy
        (no round-trip to auth-service for each request)
```

---

## 5. Deployment Pipeline Flow

```
Developer pushes to feature branch
    │
    ▼
GitHub Actions triggered
    ├── [Test] go test ./...
    ├── [Lint] golangci-lint run
    ├── [Build] docker build (multi-stage, distroless)
    ├── [Scan] trivy image --severity CRITICAL,HIGH
    │   └── Fails build if CRITICAL CVE found (prod) or HIGH (staging)
    ├── [Push] docker push to ACR
    ├── [Sign] cosign sign --key (keyless OIDC)
    ├── [SBOM] syft image → grype scan
    └── [Update] update image tag in kubernetes/overlays/prod/
            (creates PR or pushes directly to GitOps repo)
    │
    ▼
ArgoCD detects Git change (3-minute poll or webhook)
    │
    ▼
ArgoCD reconciliation loop:
    ├── Compares desired state (Git) with actual state (cluster)
    ├── Applies diff using kubectl apply
    ├── Waits for rollout to complete
    └── Reports sync status (Synced / OutOfSync / Degraded)
    │
    ▼
Istio (if canary configured):
    ├── Routes 10% traffic to new version
    ├── Prometheus monitors error rate + latency
    └── Flagger auto-promotes or rolls back based on SLO metrics
```

---

## 6. Infrastructure Architecture

```
Azure Region: East US 2
│
├── Resource Group: rg-sequence-network
│   └── VNet: 10.0.0.0/8
│       ├── snet-aks-system:  10.1.0.0/16
│       ├── snet-aks-user:    10.2.0.0/16
│       ├── snet-aks-infra:   10.3.0.0/16
│       ├── snet-postgres:    10.4.0.0/24
│       └── snet-redis:       10.5.0.0/24
│
├── Resource Group: rg-sequence-aks
│   └── AKS: aks-sequence-prod
│       ├── System Pool: Standard_D4s_v3 × 3 (zones 1,2,3)
│       ├── User Pool:   Standard_D8s_v3 × 3-10 (autoscale)
│       └── Infra Pool:  Standard_D4s_v3 × 2-4 (autoscale)
│
├── Resource Group: rg-sequence-data
│   ├── PostgreSQL Flexible Server (zone-redundant HA)
│   └── Azure Cache for Redis Premium P1 (zone-redundant)
│
└── Resource Group: rg-sequence-platform
    ├── ACR: acrsequenceprod (Premium)
    ├── Key Vault: kv-sequence-prod
    └── Log Analytics Workspace
```

---

## 7. Security Architecture Overview

```
Layer 7 — Application:    Input validation, JWT auth, rate limiting
Layer 6 — Service Mesh:   Istio mTLS, AuthorizationPolicy (deny-all default)
Layer 5 — Kubernetes:     RBAC, NetworkPolicy, PodSecurity Standards
Layer 4 — CI/CD:          Trivy scan, Cosign sign, OPA policy gate
Layer 3 — Container:      Distroless base, non-root user, read-only filesystem
Layer 2 — Infrastructure: Private endpoints, NSG, Key Vault, Managed Identity
Layer 1 — Cloud:          Defender for Containers, audit logging, RBAC
```
