#!/usr/bin/env bash
# setup-workload-identity.sh — Configure Azure Workload Identity for all services
#
# Usage: ./scripts/setup-workload-identity.sh <environment>
# Example: ./scripts/setup-workload-identity.sh prod
#
# What this does:
# 1. Creates a managed identity per service
# 2. Creates federated credential linking K8s ServiceAccount to Azure AD
# 3. Grants each identity the minimum Key Vault permissions it needs
# 4. Patches Kubernetes ServiceAccounts with the identity client ID
#
# Why Workload Identity (vs node-level MSI):
# Node-level MSI means ALL pods on a node share the same identity.
# Workload Identity is per-pod — each service gets only the permissions it needs.
# This is the principle of least privilege at the pod level.

set -euo pipefail

ENVIRONMENT="${1:-dev}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "\n${BLUE}===> $1${NC}"; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
CLUSTER_NAME="aks-sequence-${ENVIRONMENT}"
RG_AKS="rg-sequence-aks-${ENVIRONMENT}"
RG_PLATFORM="rg-sequence-platform-${ENVIRONMENT}"
KEYVAULT_NAME="kv-sequence-${ENVIRONMENT}"
NAMESPACE="sequence-${ENVIRONMENT}"

# Services that need Key Vault access
SERVICES=(auth-service game-service matchmaking-service leaderboard-service notification-service analytics-service)

# Get AKS OIDC Issuer URL (needed for federated credentials)
log_step "Getting AKS OIDC Issuer URL"
OIDC_ISSUER=$(az aks show \
  --resource-group "$RG_AKS" \
  --name "$CLUSTER_NAME" \
  --query oidcIssuerProfile.issuerUrl \
  -o tsv)
log_info "OIDC Issuer: $OIDC_ISSUER"

# ---------------------------------------------------------------------------
# Create managed identity + federated credential per service
# ---------------------------------------------------------------------------
for SERVICE in "${SERVICES[@]}"; do
  log_step "Configuring Workload Identity for: $SERVICE"
  IDENTITY_NAME="id-sequence-${SERVICE}-${ENVIRONMENT}"

  # Create User-Assigned Managed Identity
  log_info "Creating managed identity: $IDENTITY_NAME"
  az identity create \
    --resource-group "$RG_PLATFORM" \
    --name "$IDENTITY_NAME" \
    --location eastus2 \
    --tags \
      Project=sequence-game \
      Environment="$ENVIRONMENT" \
      Service="$SERVICE" \
      ManagedBy=script \
    --output none

  CLIENT_ID=$(az identity show \
    --resource-group "$RG_PLATFORM" \
    --name "$IDENTITY_NAME" \
    --query clientId -o tsv)

  PRINCIPAL_ID=$(az identity show \
    --resource-group "$RG_PLATFORM" \
    --name "$IDENTITY_NAME" \
    --query principalId -o tsv)

  log_info "Client ID: $CLIENT_ID"

  # Create federated credential: "trust tokens from this K8s ServiceAccount"
  log_info "Creating federated credential"
  az identity federated-credential create \
    --name "fc-${SERVICE}-${ENVIRONMENT}" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RG_PLATFORM" \
    --issuer "$OIDC_ISSUER" \
    --subject "system:serviceaccount:${NAMESPACE}:${SERVICE}" \
    --audiences api://AzureADTokenExchange \
    --output none

  # Grant Key Vault Secrets User role
  log_info "Granting Key Vault Secrets User role"
  KEYVAULT_RESOURCE_ID=$(az keyvault show \
    --name "$KEYVAULT_NAME" \
    --resource-group "$RG_PLATFORM" \
    --query id -o tsv)

  az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --scope "$KEYVAULT_RESOURCE_ID" \
    --output none

  # Patch Kubernetes ServiceAccount with Azure identity annotation
  log_info "Patching Kubernetes ServiceAccount"
  kubectl annotate serviceaccount "$SERVICE" \
    --namespace "$NAMESPACE" \
    "azure.workload.identity/client-id=${CLIENT_ID}" \
    --overwrite

  # Add Workload Identity label (required by webhook)
  kubectl label serviceaccount "$SERVICE" \
    --namespace "$NAMESPACE" \
    "azure.workload.identity/use=true" \
    --overwrite

  log_info "Workload Identity configured for $SERVICE ✓"
done

log_step "Workload Identity setup complete for all services in $ENVIRONMENT"
log_info ""
log_info "Verify with:"
log_info "  kubectl get serviceaccounts -n $NAMESPACE -o yaml | grep azure.workload.identity"
