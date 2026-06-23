# Architecture Reference
## Cloud, AKS, Istio, Security, SRE, and DR

**Version:** 1.0  
**Date:** 2026-06-22

---

## 1. Azure Cloud Architecture

### Resource Topology

```
Azure Subscription: sequence-game-sub
│
├── Resource Group: rg-sequence-network
│   ├── Virtual Network: vnet-sequence (10.0.0.0/8)
│   │   ├── snet-aks-system:  10.1.0.0/16  ← System node pool
│   │   ├── snet-aks-user:    10.2.0.0/16  ← User workloads
│   │   ├── snet-aks-infra:   10.3.0.0/16  ← Platform services
│   │   ├── snet-postgres:    10.4.0.0/24  ← Private endpoint
│   │   └── snet-redis:       10.5.0.0/24  ← Private endpoint
│   ├── Private DNS Zones
│   │   ├── privatelink.postgres.database.azure.com
│   │   └── privatelink.redis.cache.windows.net
│   └── Network Security Groups (per subnet)
│
├── Resource Group: rg-sequence-aks
│   ├── AKS Cluster: aks-sequence-prod
│   │   ├── System Node Pool (Standard_D4s_v3, 3 nodes, zones 1/2/3)
│   │   ├── User Node Pool   (Standard_D8s_v3, 3-10 nodes, autoscale)
│   │   └── Infra Node Pool  (Standard_D4s_v3, 2-4 nodes, autoscale)
│   └── Managed Identities
│       ├── aks-cluster-identity (SystemAssigned)
│       └── aks-kubelet-identity (UserAssigned)
│
├── Resource Group: rg-sequence-data
│   ├── PostgreSQL Flexible Server: psql-sequence-prod
│   │   ├── Zone-redundant HA (primary zone 1, standby zone 2)
│   │   ├── 4 vCores, 16GB RAM, 256GB storage
│   │   └── Private endpoint in snet-postgres
│   └── Azure Cache for Redis: redis-sequence-prod
│       ├── Premium P1, 6GB, zone-redundant
│       └── Private endpoint in snet-redis
│
├── Resource Group: rg-sequence-platform
│   ├── Azure Container Registry: acrsequenceprod (Premium)
│   │   └── Private link + geo-replication
│   ├── Azure Key Vault: kv-sequence-prod
│   │   ├── Soft-delete: enabled (90 days)
│   │   ├── Purge protection: enabled
│   │   └── Private endpoint
│   └── Log Analytics Workspace: law-sequence-prod
│       └── Retention: 90 days
│
└── Resource Group: rg-sequence-security
    └── Microsoft Defender for Containers: enabled
```

---

## 2. AKS Architecture

### Node Pool Design

```
┌────────────────────────────────────────────────────────────────┐
│                       AKS CLUSTER                              │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                SYSTEM NODE POOL                          │  │
│  │  VM: Standard_D4s_v3 (4 vCPU, 16GB RAM)                │  │
│  │  Count: 3 (one per AZ — 1, 2, 3)                       │  │
│  │  Taint: CriticalAddonsOnly=true:NoSchedule             │  │
│  │  OS Disk: Ephemeral 128GB                               │  │
│  │  Workloads: CoreDNS, kube-proxy, Istio control plane   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            USER NODE POOL (game workloads)               │  │
│  │  VM: Standard_D8s_v3 (8 vCPU, 32GB RAM)                │  │
│  │  Count: 3-10 (Cluster Autoscaler)                       │  │
│  │  Label: workload=game                                   │  │
│  │  OS Disk: Ephemeral 128GB                               │  │
│  │  Workloads: auth, game, matchmaking, leaderboard, etc.  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           INFRA NODE POOL (platform services)            │  │
│  │  VM: Standard_D4s_v3 (4 vCPU, 16GB RAM)                │  │
│  │  Count: 2-4 (Cluster Autoscaler)                        │  │
│  │  Label: workload=platform                               │  │
│  │  Taint: workload=platform:NoSchedule                    │  │
│  │  Workloads: ArgoCD, Prometheus, Grafana, Loki, Tempo    │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Why Ephemeral OS Disks

Ephemeral OS disks are stored on node VM temp storage (NVMe SSD), not a managed disk. Benefits:
- Zero OS disk cost (included in VM price)
- Lower latency for OS operations
- Automatic reset on node reimage (nodes are cattle, not pets)

Trade-off: Node state is lost on VM reimage — all application state must be in external storage (Redis, Postgres). This is the correct cloud-native approach.

### Workload Identity Architecture

```
Step 1: AKS cluster has OIDC Issuer URL enabled
        (https://oidc.prod.aks.azure.com/{clusterId})

Step 2: Azure AD Federated Credential configured:
        "Trust tokens from AKS OIDC issuer for ServiceAccount
         'auth-service' in namespace 'sequence-prod'"

Step 3: Pod ServiceAccount annotated:
        azure.workload.identity/client-id: <managed-identity-client-id>

Step 4: Workload Identity webhook injects into pod:
        AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE

Step 5: Azure SDK exchanges K8s OIDC token for Azure access token
        (automatic, no code change needed)

Step 6: Pod accesses Key Vault secrets with zero credentials stored
```

---

## 3. Istio Architecture

### Control Plane Components

```
istiod (single control plane pod)
  ├── Pilot:   Pushes xDS configuration to Envoy sidecars
  ├── Citadel: Issues and rotates mTLS certificates (SPIFFE/X.509)
  └── Galley:  Validates Istio configuration (webhook)
```

### Data Plane

Every pod in an Istio-enabled namespace gets an Envoy sidecar injected automatically (label: `istio-injection: enabled` on namespace).

```
Pod: game-service-7d8f9b6c4-xk2p9
  Container 1: game-service (your application)
  Container 2: istio-proxy  (Envoy sidecar, injected automatically)
  InitContainer: istio-init (configures iptables to intercept traffic)
```

All traffic in/out of the pod is intercepted by Envoy. Your application code does not need to handle TLS, retries, or circuit breaking.

### Key Istio Resources

| Resource | Purpose | Scope |
|---|---|---|
| Gateway | Defines Ingress (external → mesh) | Cluster |
| VirtualService | Traffic routing rules | Namespace |
| DestinationRule | Load balancing + circuit breaker config | Namespace |
| PeerAuthentication | mTLS policy (STRICT/PERMISSIVE/DISABLE) | Namespace/Pod |
| AuthorizationPolicy | L7 access control (who can call what) | Namespace/Pod |
| ServiceEntry | Register external services in the mesh | Namespace |
| RequestAuthentication | JWT validation policy | Namespace |

### mTLS Configuration

```yaml
# Enforce strict mTLS across entire production namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: sequence-prod
spec:
  mtls:
    mode: STRICT  # No plaintext allowed between pods
```

Effect: Every pod-to-pod communication uses mutual TLS. Certificates rotate every 24 hours automatically. No manual certificate management.

### Canary Deployment Flow

```
Traffic split during canary:
  game-service v1.2.0 (stable):  90% of traffic
  game-service v1.3.0 (canary):  10% of traffic

Promotion criteria (Flagger + Prometheus):
  - Error rate < 1% over 5 minutes
  - p99 latency < 200ms
  If both pass: increment weight by 10% every 2 minutes
  If either fails: immediate rollback to v1.2.0
```

### Circuit Breaker Configuration

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: game-service
  namespace: sequence-prod
spec:
  host: game-service
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 5      # Eject pod after 5 consecutive 5xx
      interval: 30s                # Check every 30 seconds
      baseEjectionTime: 30s        # Keep ejected for 30 seconds
      maxEjectionPercent: 50       # Never eject more than 50% of pods
```

Effect: If a pod starts failing (bad deploy, OOM, upstream failure), Istio automatically removes it from the load balancer pool for 30 seconds. Traffic is redirected to healthy pods. No code change needed.

---

## 4. Security Architecture

### Defense-in-Depth (7 Layers)

```
Layer 7 — Application Layer
  • Input validation on all API endpoints
  • JWT authentication (RS256)
  • Rate limiting (5 req/min for auth endpoints)
  • SQL parameterized queries (no SQL injection)

Layer 6 — Service Mesh Layer (Istio)
  • mTLS: STRICT mode — all pod-to-pod traffic encrypted + authenticated
  • AuthorizationPolicy: default deny-all, explicit allow-list
  • JWT validation: Istio validates tokens before reaching application
  • Rate limiting: Envoy local rate limit filter

Layer 5 — Kubernetes Layer
  • RBAC: least-privilege service accounts per namespace
  • NetworkPolicy: pods can only talk to what they need
  • PodSecurity Standards: Restricted profile in production
  • Admission webhooks: Kyverno + OPA Gatekeeper

Layer 4 — CI/CD Layer
  • Trivy: scan image for CVEs before push
  • Cosign: sign images with keyless OIDC (Sigstore)
  • Kyverno: reject unsigned images at admission
  • SBOM: Software Bill of Materials generated per build

Layer 3 — Container Layer
  • Distroless base images (no shell, no package manager)
  • Non-root user (UID 65532)
  • Read-only root filesystem
  • No privilege escalation (allowPrivilegeEscalation: false)
  • Drop all Linux capabilities

Layer 2 — Infrastructure Layer
  • Private endpoints for PostgreSQL, Redis, ACR, Key Vault
  • NSG rules: deny all, allow only required ports
  • Azure Key Vault: no credentials in environment variables
  • Workload Identity: pods access Azure services without credentials
  • Managed Identities: no client secrets

Layer 1 — Cloud/Compliance Layer
  • Microsoft Defender for Containers: threat detection
  • Azure Policy: enforce resource tagging, allowed locations
  • Azure Activity Log: all control-plane operations logged
  • Entra ID (Azure AD): human access via OIDC, MFA required
```

### Supply Chain Security (SLSA Level 2)

```
1. Source: GitHub branch protection + required reviews
2. Build: GitHub Actions (ephemeral, tamper-evident)
3. SBOM: Syft generates SBOM for every image
4. Scan: Grype scans SBOM for known vulnerabilities
5. Sign: Cosign signs image (keyless, OIDC-backed)
   Signature stored in ACR as OCI artifact
6. Verify: Kyverno verifies signature at pod admission
   Unsigned images are rejected in staging + prod
```

---

## 5. SRE Architecture

### SLI Definitions

```
Availability SLI:
  "The percentage of HTTP requests to {service} that return
   a non-5xx response over a 5-minute window"

  prometheus_expr:
    sum(rate(http_requests_total{service=~"$service",code!~"5.."}[5m]))
    /
    sum(rate(http_requests_total{service=~"$service"}[5m]))

Latency SLI:
  "The percentage of HTTP requests to {service} that complete
   in less than {threshold}ms"

  prometheus_expr:
    sum(rate(http_request_duration_seconds_bucket{
      service=~"$service", le="0.2"  # 200ms threshold
    }[5m]))
    /
    sum(rate(http_request_duration_seconds_count{service=~"$service"}[5m]))
```

### SLO → Error Budget Calculation

```
SLO: 99.5% availability over 28 days

Total minutes in 28 days: 28 × 24 × 60 = 40,320 minutes
Allowed failure minutes:  40,320 × 0.005 = 201.6 minutes
Error budget:             201 minutes 36 seconds

Interpretation:
  At 100% error budget remaining: deploy freely
  At 50% remaining:               slow down risky changes
  At 10% remaining:               freeze non-critical deployments
  At 0% remaining:                freeze all, post-mortem required
```

### Burn Rate Alerting (Multi-Window)

```
Fast burn alert (1h window):
  If error rate > 14× the allowed rate → alert immediately
  Reason: at this rate, full 28-day budget burns in 48 hours

Slow burn alert (6h window):
  If error rate > 5× the allowed rate → alert after 1 hour
  Reason: subtle degradation that would exhaust budget in 5-6 days

Both alerts use Prometheus. Pages go to PagerDuty.
```

---

## 6. Disaster Recovery Strategy

### Recovery Objectives

| Scenario | RTO | RPO |
|---|---|---|
| Single pod crash | < 30s | 0 (K8s self-heals) |
| Node failure | < 5 min | 0 (pods reschedule) |
| AZ outage | < 10 min | < 1 min |
| Full region outage | < 4 hours | < 5 min |
| Data corruption | < 2 hours | < 5 min (PITR) |

### Multi-AZ Resilience

- AKS nodes spread across 3 AZs (PodTopologySpreadConstraints)
- PostgreSQL: zone-redundant HA (synchronous standby in AZ2)
- Redis: zone-redundant Premium (replica in AZ3)
- All critical pods: `topologySpreadConstraints` to spread across AZs

### Backup Strategy

```
PostgreSQL:
  - Automated full backup: Azure-managed, weekly
  - WAL shipping: continuous, stored in Azure Blob
  - PITR window: 35 days
  - Test restore: monthly automated runbook

Redis:
  - RDB snapshot: every 60 minutes → Azure Blob Storage
  - Data loss on restore: up to 60 minutes of session data
  - Acceptable because: active games re-deal from saved checkpoint

Kubernetes Configuration:
  - All config is in Git (GitOps) — Git IS the backup
  - Secrets: in Key Vault (soft-delete + purge protection)
  - PersistentVolumes: Velero backs up to Azure Blob (Prometheus, Loki)
```
