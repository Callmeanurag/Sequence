# ADR-002: Azure Kubernetes Service (AKS) over Self-Managed Kubernetes

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

Kubernetes can be self-managed (kubeadm, k3s, kops) or fully managed (AKS, EKS, GKE). Self-managed gives full control over the control plane; managed services abstract it away.

## Decision

Use Azure Kubernetes Service (AKS) with the following configuration:
- Kubernetes version: 1.29+
- CNI: Azure CNI
- OIDC Issuer: enabled (for Workload Identity)
- Azure AD integration: enabled (for RBAC)
- Key Vault Secrets Provider: enabled (CSI Driver)

## Rationale

**AKS advantages for this project:**

1. **Managed control plane:** Azure manages etcd, API server, scheduler HA. No operational overhead managing control plane nodes.

2. **Workload Identity integration:** Native OIDC integration with Azure AD. Pods access Azure services (Key Vault, ACR) without credentials — a critical security practice.

3. **Azure CNI:** Pods get real Azure VNet IPs. Enables Network Policies via Azure NPM. Direct routing from Azure services to pod IPs (no NAT).

4. **Native Azure Monitor integration:** Automatic scraping of Prometheus metrics. Container Insights for node/pod metrics out of the box.

5. **Managed node upgrades:** Rolling node upgrades with configurable surge settings. Reduces upgrade operational burden.

## Consequences

**Positive:**
- Zero control plane management overhead
- Native integration with Azure AD, Key Vault, ACR, Monitor
- Workload Identity eliminates credential management for pods
- Zone-redundant control plane included

**Negative:**
- Less control over API server configuration
- Azure-specific features (Workload Identity OIDC) require Azure-specific Terraform
- Control plane version upgrade window managed by Azure policy

## Alternatives Considered

**Self-managed with kubeadm:** Rejected. Managing etcd backups, API server certificates, and control plane HA would consume time better spent on DevOps tooling. kubeadm is valuable to learn separately, but this project prioritizes platform engineering depth.

**k3s on Azure VMs:** Rejected. Production-grade k3s requires substantial operational investment. Does not integrate with Azure AD or Key Vault natively.

## Interview Guidance

**Common question:** "What is the difference between the AKS cluster managed identity and pod Workload Identity?"

Answer: "The cluster managed identity is used by AKS infrastructure components (like the node pool VM scale set) to interact with Azure APIs — for example, creating load balancers or attaching disks. Workload Identity is per-pod and per-service-account. It allows individual pods to authenticate to Azure services using their Kubernetes service account token, federated through Azure AD OIDC. This means each microservice gets only the Key Vault permissions it needs — principle of least privilege at the pod level."
