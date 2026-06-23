#!/usr/bin/env bash
# install-argocd.sh — Install ArgoCD with production configuration
#
# Usage: ./scripts/install-argocd.sh

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "\n${BLUE}===> $1${NC}"; }

ARGOCD_VERSION="v2.10.0"

log_step "Adding ArgoCD Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm --force-update

log_step "Installing ArgoCD $ARGOCD_VERSION"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version 6.7.0 \
  --set server.service.type=ClusterIP \
  --set server.extraArgs="{--insecure}" \
  --set configs.params."server\.insecure"=true \
  --set controller.replicas=1 \
  --set server.replicas=2 \
  --set repoServer.replicas=2 \
  --set applicationSet.replicaCount=2 \
  --set global.nodeSelector.workload=platform \
  --set global.tolerations[0].key=workload \
  --set global.tolerations[0].operator=Equal \
  --set global.tolerations[0].value=platform \
  --set global.tolerations[0].effect=NoSchedule \
  --wait --timeout=10m

log_info "ArgoCD installed. Waiting for pods to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server \
  --namespace argocd --timeout=300s

log_step "Getting initial admin password"
INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

log_info "ArgoCD is ready!"
log_info ""
log_info "Port-forward to access UI:"
log_info "  kubectl port-forward svc/argocd-server -n argocd 8080:80"
log_info "  Open: http://localhost:8080"
log_info "  Username: admin"
log_info "  Password: $INITIAL_PASSWORD"
log_info ""
log_info "IMPORTANT: Change the admin password immediately:"
log_info "  argocd login localhost:8080 --username admin --password '$INITIAL_PASSWORD' --insecure"
log_info "  argocd account update-password"
