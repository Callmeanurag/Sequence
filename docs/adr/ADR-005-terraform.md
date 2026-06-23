# ADR-005: Terraform over Bicep/Pulumi for Infrastructure as Code

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

Azure infrastructure can be declared with Terraform (HCL), Bicep (Azure-native DSL), Pulumi (general programming languages), or ARM templates (JSON).

## Decision

Use Terraform with Azure Blob Storage backend for remote state.

## Rationale

| Dimension | Terraform | Bicep | Pulumi |
|---|---|---|---|
| Cloud agnostic | Yes | Azure only | Yes |
| Language | HCL (declarative) | Bicep DSL | Python/TypeScript/Go |
| State management | Remote state + locking | No state file | State backend |
| Module ecosystem | Terraform Registry (largest) | Bicep Registry | Pulumi Registry |
| Community | Largest | Azure-focused | Growing |
| Interview value | Highest | Azure roles only | High (but niche) |
| Learning curve | Medium | Low | Low-Medium |

**Why Terraform over Bicep:**
Bicep is Azure-specific. Terraform skills transfer to AWS and GCP. This project targets career growth — Terraform is asked in almost every senior DevOps interview regardless of cloud provider.

## Implementation

**Module structure:**
```
infrastructure/
├── modules/           # Reusable modules (no provider block)
│   ├── aks/           # AKS cluster + node pools
│   ├── networking/    # VNet + subnets + NSG + private DNS
│   ├── acr/           # Azure Container Registry
│   ├── postgresql/    # PostgreSQL Flexible Server
│   ├── redis/         # Azure Cache for Redis
│   └── keyvault/      # Azure Key Vault + access policies
└── environments/      # Root modules (call modules, define tfvars)
    ├── dev/
    ├── staging/
    └── prod/
```

**Remote state:**
```hcl
# backend.tf (per environment)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-sequence-tfstate"
    storage_account_name = "stsequencetfstate"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
    # State locking: Azure Blob lease (automatic)
  }
}
```

**Why remote state matters:**
Local state is lost if the workstation is destroyed. Remote state enables team collaboration. Azure Blob Storage uses blob leases for distributed locking — prevents two `terraform apply` operations from corrupting the state file simultaneously.

## Consequences

**Positive:**
- Cloud-agnostic skills — same HCL patterns work on AWS/GCP
- Largest module ecosystem (Terraform Registry)
- Remote state with locking prevents concurrent apply corruption
- Environment isolation via separate state files
- `terraform plan` provides an explicit preview before any change

**Negative:**
- HCL is not a general programming language (loops are limited vs Pulumi)
- State file contains sensitive data — must be encrypted and access-controlled
- Provider version pinning is critical (breaking changes between versions)

## Interview Guidance

**Question:** "How do you manage Terraform state across multiple environments?"

Answer: "Each environment (dev, staging, prod) has its own state file stored in Azure Blob Storage with a unique key path. This isolation means a `terraform apply` in dev never touches prod state. We use Azure Blob Storage blob leases for state locking — when someone runs `terraform apply`, Terraform acquires an exclusive lease on the blob. Any concurrent apply fails immediately with a lock error, preventing state corruption. The storage account itself has versioning enabled, so we can recover from accidental state corruption by restoring a previous blob version."

**Question:** "What happens if two engineers run terraform apply simultaneously?"

Answer: "The first engineer's Terraform acquires an Azure Blob lease on the state file. The second engineer's Terraform attempts to acquire the same lease, fails, and prints an error: 'Error acquiring the state lock.' They must wait for the first apply to complete and the lease to be released. This is automatic and requires no manual coordination."
