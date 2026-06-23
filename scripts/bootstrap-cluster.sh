#!/usr/bin/env bash
# bootstrap-cluster.sh — Full cluster bootstrap from zero to ArgoCD
#
# Usage: ./scripts/bootstrap-cluster.sh <environment>
# Example: ./scripts/bootstrap-cluster.sh dev
#
# What this script does (in order):
# 1. Validates prerequisites
# 2. Gets AKS credentials
# 3. Installs cert-manager (TLS certificates)
# 4. Installs Istio (service mesh)
# 5. Installs KEDA (event-driven autoscaler)
# 6. Installs Kyverno (admission controller)
# 7. Installs ArgoCD
# 8. Applies ArgoCD AppProjects
# 9. Deploys root App-of-Apps
# 10. Installs observability stack (Prometheus, Loki, Tempo)

set -euo pipefail

ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}===> $1${NC}"; }

# ---------------------------------------------------------------------------
# Step 0: Validate prerequisites
# ---------------------------------------------------------------------------
log_step "Validating prerequisites"

REQUIRED_TOOLS=(kubectl helm istioctl az argocd)
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    log_error "Required tool not found: $tool"
    exit 1
  fi
  log_info "$tool: $(command -v $tool)"
done

# Verify Azure login
if ! az account show &>/dev/null; then
  log_error "Not logged into Azure. Run: az login"
  exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
log_info "Azure subscription: $SUBSCRIPTION"

# ---------------------------------------------------------------------------
# Step 1: Get AKS credentials
# ---------------------------------------------------------------------------
log_step "Getting AKS credentials for environment: $ENVIRONMENT"

CLUSTER_NAME="aks-sequence-${ENVIRONMENT}"
RG_NAME="rg-sequence-aks-${ENVIRONMENT}"

az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

kubectl cluster-info
log_info "Connected to cluster: $CLUSTER_NAME"

# ---------------------------------------------------------------------------
# Step 2: Install cert-manager
# ---------------------------------------------------------------------------
log_step "Installing cert-manager"

helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.4 \
  --set installCRDs=true \
  --wait

log_info "cert-manager installed"

# ---------------------------------------------------------------------------
# Step 3: Install Istio
# ---------------------------------------------------------------------------
log_step "Installing Istio"

istioctl install --set profile=production -y

# Enable Istio tracing to Tempo
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    enableTracing: true
    defaultConfig:
      tracing:
        zipkin:
          address: tempo.monitoring.svc.cluster.local:9411
EOF

log_info "Istio installed with production profile"

# Apply Istio platform configs
kubectl apply -f "${REPO_ROOT}/kubernetes/platform/istio/"

# ---------------------------------------------------------------------------
# Step 4: Install KEDA
# ---------------------------------------------------------------------------
log_step "Installing KEDA"

helm repo add kedacore https://kedacore.github.io/charts --force-update
helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --wait

log_info "KEDA installed"

# ---------------------------------------------------------------------------
# Step 5: Install Kyverno
# ---------------------------------------------------------------------------
log_step "Installing Kyverno"

helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=3 \
  --wait

# Apply security policies
kubectl apply -f "${REPO_ROOT}/security/kyverno/"

log_info "Kyverno installed with policies"

# ---------------------------------------------------------------------------
# Step 6: Install observability stack
# ---------------------------------------------------------------------------
log_step "Installing observability stack"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f "${REPO_ROOT}/observability/prometheus/values.yaml" \
  --wait --timeout=10m

helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  -f "${REPO_ROOT}/observability/loki/values.yaml" \
  --wait

helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  -f "${REPO_ROOT}/observability/tempo/values.yaml" \
  --wait

log_info "Observability stack installed"

# ---------------------------------------------------------------------------
# Step 7: Install ArgoCD
# ---------------------------------------------------------------------------
log_step "Installing ArgoCD"

"${SCRIPT_DIR}/install-argocd.sh"

# ---------------------------------------------------------------------------
# Step 8: Apply AppProjects and bootstrap
# ---------------------------------------------------------------------------
log_step "Applying ArgoCD AppProjects"
kubectl apply -f "${REPO_ROOT}/gitops/bootstrap/argocd-projects.yaml"

log_step "Deploying App-of-Apps (root application)"
kubectl apply -f "${REPO_ROOT}/gitops/bootstrap/root-app.yaml"

log_info "Bootstrap complete! ArgoCD is now reconciling all applications."
log_info ""
log_info "Access ArgoCD UI:"
log_info "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
log_info "  https://localhost:8080"
log_info ""
log_info "Get initial admin password:"
log_info "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
