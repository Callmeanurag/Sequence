#!/usr/bin/env bash
# teardown.sh — Safely destroy a non-production environment to save costs
#
# Usage: ./scripts/teardown.sh <environment>
# Example: ./scripts/teardown.sh dev
#
# NEVER run against prod — the script enforces this.

set -euo pipefail

ENVIRONMENT="${1:-}"

if [[ -z "$ENVIRONMENT" ]]; then
  echo "Usage: $0 <environment>"
  exit 1
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  echo "ERROR: Will not teardown production environment. Use Azure Portal if truly needed."
  exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}WARNING: About to destroy environment: $ENVIRONMENT${NC}"
echo "This will delete:"
echo "  - AKS cluster: aks-sequence-$ENVIRONMENT"
echo "  - PostgreSQL server: psql-sequence-$ENVIRONMENT"
echo "  - Redis cache: redis-sequence-$ENVIRONMENT"
echo "  - All associated resource groups"
echo ""
read -rp "Type the environment name to confirm: " CONFIRM

if [[ "$CONFIRM" != "$ENVIRONMENT" ]]; then
  echo "Confirmation mismatch. Aborting."
  exit 1
fi

echo -e "${GREEN}Running terraform destroy for $ENVIRONMENT...${NC}"

cd "$(dirname "$0")/../infrastructure/environments/$ENVIRONMENT"

terraform init
terraform destroy \
  -var="postgres_admin_password=dummy-for-destroy" \
  -auto-approve

echo -e "${GREEN}Teardown complete for $ENVIRONMENT${NC}"
