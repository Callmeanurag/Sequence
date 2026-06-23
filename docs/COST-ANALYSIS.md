# Cost Analysis
## Sequence Platform — Azure Monthly Costs

**Date:** 2026-06-22  
**Region:** East US 2

---

## Production Environment (Full Scale)

| Resource | SKU | Quantity | Monthly USD |
|---|---|---|---|
| AKS System Node Pool | Standard_D4s_v3 (4 vCPU, 16GB) | 3 nodes | $435 |
| AKS User Node Pool (avg) | Standard_D8s_v3 (8 vCPU, 32GB) | 5 nodes | $1,215 |
| AKS Infra Node Pool (avg) | Standard_D4s_v3 (4 vCPU, 16GB) | 2 nodes | $290 |
| PostgreSQL Flexible Server | 4 vCores, 16GB, Zone-HA | 1 | $385 |
| Azure Cache for Redis | Premium P1 (6GB), Zone-Redundant | 1 | $280 |
| Azure Container Registry | Premium (geo-replication) | 1 | $50 |
| Azure Key Vault | Standard, ~100 operations/day | 1 | $5 |
| Azure Monitor + Log Analytics | ~20GB/day ingestion | 1 | $150 |
| Azure Blob Storage (Terraform state, backups) | LRS, ~100GB | 1 | $5 |
| Azure Private DNS Zones | 2 zones | 2 | $2 |
| Egress Bandwidth | ~500GB/month | — | $45 |
| AKS Control Plane | Uptime SLA tier | 1 | $73 |
| **Total Production** | | | **~$2,935/month** |

---

## Learning / Development Environment (Cost-Optimized)

For learning, you do NOT need the full production setup. Here is how to run this for $200-300/month:

| Resource | Optimization | Original SKU | Optimized SKU | Savings |
|---|---|---|---|---|
| AKS User Nodes | Use B-series (burstable) | Standard_D8s_v3 × 5 | Standard_B4ms × 3 | ~80% |
| AKS System Nodes | Reduce to 1 node | Standard_D4s_v3 × 3 | Standard_B2ms × 1 | ~90% |
| PostgreSQL | Burstable tier | 4 vCores Zone-HA | Burstable B2ms | ~85% |
| Redis | Basic C0 (no persistence) | Premium P1 | Basic C0 | ~90% |
| Cluster schedule | Auto-shutdown nights/weekends | 24/7 | 10h/day weekdays | ~60% |
| ACR | Basic tier | Premium | Basic | ~70% |
| **Total Dev/Learning** | | **$2,935** | **~$200-280/month** | **~90%** |

### Learning Environment Terraform Variables

```hcl
# environments/dev/terraform.tfvars
environment            = "dev"
system_node_vm_size    = "Standard_B2ms"
user_node_vm_size      = "Standard_B4ms"
user_node_min_count    = 1
user_node_max_count    = 3
infra_node_vm_size     = "Standard_B2ms"
postgres_sku           = "B_Standard_B2ms"  # Burstable
redis_sku_name         = "Basic"
redis_family           = "C"
redis_capacity         = 0                  # C0 = 250MB
acr_sku                = "Basic"
enable_zone_redundancy = false
```

---

## Cost Optimization Strategies

### 1. Spot Node Pool for User Workload

Azure Spot VMs can be 60-80% cheaper than regular VMs. They can be evicted with 30 seconds notice, but game-service pods are stateless (state in Redis), so eviction is handled gracefully.

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "user_spot" {
  name       = "userspot"
  priority   = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1  # Pay market price (up to On-Demand)
  
  # Spot nodes are automatically tainted:
  # kubernetes.azure.com/scalesetpriority=spot:NoSchedule
  # Application pods must tolerate this taint
}
```

### 2. Cluster Auto-Shutdown (Nights/Weekends)

Save 60% by stopping AKS during off-hours for the development cluster.

```bash
# Azure Automation Runbook: stop-dev-cluster
az aks stop --resource-group rg-sequence-aks --name aks-sequence-dev

# Morning start
az aks start --resource-group rg-sequence-aks --name aks-sequence-dev
```

### 3. Reserved Instances (Production)

For production, commit to 1-year or 3-year reserved instances:
- 1-year savings: ~40%
- 3-year savings: ~65%

At the current estimate: $2,935/month × 0.60 (1yr reserved) = **~$1,760/month**

### 4. Right-sizing with VPA

Vertical Pod Autoscaler (VPA) in recommendation mode provides sizing recommendations without auto-applying. Review weekly and adjust resource requests.

```bash
kubectl get vpa -n sequence-prod
# Shows: LOWER BOUND, TARGET, UPPER BOUND for each container
```

---

## Cost Tagging Strategy

All Azure resources are tagged for cost allocation:

```hcl
locals {
  common_tags = {
    Project     = "sequence-game"
    Environment = var.environment      # dev | staging | prod
    ManagedBy   = "terraform"
    CostCenter  = "devops-learning"
    Owner       = "anurag-raj"
    Repository  = "github.com/Callmeanurag/Sequence"
  }
}
```

Azure Policy enforces required tags at resource creation — any resource without these tags is blocked. This ensures every dollar is attributed to a team/project.

---

## Monthly Cost Tracking

Use Azure Cost Management to set up:
1. Budget alerts at 80% and 100% of monthly budget
2. Cost analysis grouped by tag (Project, Environment)
3. Anomaly detection (Azure Cost Management built-in)

```bash
# View current month costs via CLI
az consumption usage list \
  --start-date $(date -d "$(date +%Y-%m-01)" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?tags.Project=='sequence-game']" \
  --output table
```
