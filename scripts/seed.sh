#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Zetdo Infrastructure Seed Script
#
# Creates chicken-and-egg resources that must exist before CI/CD can work.
# This script is idempotent - safe to re-run at any time.
#
# Prerequisites:
#   - Azure CLI installed and logged in with admin permissions
#   - Access to all three subscriptions (dev, sit, prod)
#
# Usage:
#   export DEV_SUBSCRIPTION_ID="..."
#   export SIT_SUBSCRIPTION_ID="..."
#   export PROD_SUBSCRIPTION_ID="..."
#   ./scripts/seed.sh
# =============================================================================

# --- Configuration ---
LOCATION="westeurope"
LOCATION_SHORT="weu"
GITHUB_ORG="ramonbrbs"
GITHUB_REPO="Zetdo.Infra"

# Subscription IDs (required environment variables)
DEV_SUBSCRIPTION_ID="${DEV_SUBSCRIPTION_ID:?Set DEV_SUBSCRIPTION_ID}"
SIT_SUBSCRIPTION_ID="${SIT_SUBSCRIPTION_ID:?Set SIT_SUBSCRIPTION_ID}"
PROD_SUBSCRIPTION_ID="${PROD_SUBSCRIPTION_ID:?Set PROD_SUBSCRIPTION_ID}"

# Deterministic resource names (matching existing naming convention)
TFSTATE_RG="rg-zetdo-tfstate"
TFSTATE_SA="stzetdotfstate${LOCATION_SHORT}"
SHARED_RG="rg-zetdo-shared-${LOCATION_SHORT}"
DEV_RG="rg-zetdo-dev-${LOCATION_SHORT}"
SIT_RG="rg-zetdo-sit-${LOCATION_SHORT}"
PROD_RG="rg-zetdo-prod-${LOCATION_SHORT}"
APP_NAME="zetdo-github-actions"

# =============================================================================
# Helper functions
# =============================================================================

create_federated_credential() {
  local APP_OBJECT_ID="$1"
  local NAME="$2"
  local SUBJECT="$3"
  local DESCRIPTION="$4"

  EXISTING=$(az ad app federated-credential list --id "$APP_OBJECT_ID" \
    --query "[?name=='${NAME}'].name" -o tsv 2>/dev/null || true)
  if [ -z "$EXISTING" ]; then
    az ad app federated-credential create --id "$APP_OBJECT_ID" \
      --parameters "{
        \"name\": \"${NAME}\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"${SUBJECT}\",
        \"audiences\": [\"api://AzureADTokenExchange\"],
        \"description\": \"${DESCRIPTION}\"
      }" --only-show-errors
    echo "  Created: $NAME"
  else
    echo "  Already exists: $NAME"
  fi
}

assign_role() {
  local SCOPE="$1"
  local ROLE="$2"
  local SP_OBJECT_ID="$3"

  EXISTING=$(az role assignment list --scope "$SCOPE" \
    --assignee "$SP_OBJECT_ID" --role "$ROLE" --query "[0].id" -o tsv 2>/dev/null || true)
  if [ -z "$EXISTING" ]; then
    az role assignment create --scope "$SCOPE" \
      --assignee-object-id "$SP_OBJECT_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "$ROLE" --only-show-errors
    echo "  Assigned: $ROLE on $(basename "$SCOPE")"
  else
    echo "  Already assigned: $ROLE on $(basename "$SCOPE")"
  fi
}

# =============================================================================
# 1. Resource Groups
# =============================================================================
echo "=== Creating resource groups ==="

# Terraform state RG (dev subscription)
az group create --subscription "$DEV_SUBSCRIPTION_ID" \
  --name "$TFSTATE_RG" --location "$LOCATION" \
  --tags project=zetdo managed_by=seed purpose=terraform-state \
  --only-show-errors -o none
echo "  $TFSTATE_RG (dev subscription)"

# Shared resources RG (dev subscription)
az group create --subscription "$DEV_SUBSCRIPTION_ID" \
  --name "$SHARED_RG" --location "$LOCATION" \
  --tags project=zetdo managed_by=seed purpose=shared-resources \
  --only-show-errors -o none
echo "  $SHARED_RG (dev subscription)"

# Environment RGs (each in own subscription)
az group create --subscription "$DEV_SUBSCRIPTION_ID" \
  --name "$DEV_RG" --location "$LOCATION" \
  --tags project=zetdo environment=dev managed_by=terraform \
  --only-show-errors -o none
echo "  $DEV_RG (dev subscription)"

az group create --subscription "$SIT_SUBSCRIPTION_ID" \
  --name "$SIT_RG" --location "$LOCATION" \
  --tags project=zetdo environment=sit managed_by=terraform \
  --only-show-errors -o none
echo "  $SIT_RG (sit subscription)"

az group create --subscription "$PROD_SUBSCRIPTION_ID" \
  --name "$PROD_RG" --location "$LOCATION" \
  --tags project=zetdo environment=prod managed_by=terraform \
  --only-show-errors -o none
echo "  $PROD_RG (prod subscription)"

# =============================================================================
# 2. State Storage
# =============================================================================
echo ""
echo "=== Creating state storage ==="

az storage account create --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$TFSTATE_RG" \
  --name "$TFSTATE_SA" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags project=zetdo managed_by=seed \
  --only-show-errors -o none
echo "  Storage account: $TFSTATE_SA"

# Enable blob versioning
az storage account blob-service-properties update \
  --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$TFSTATE_RG" \
  --account-name "$TFSTATE_SA" \
  --enable-versioning true \
  --only-show-errors -o none
echo "  Blob versioning enabled"

# Create containers (one per environment + shared)
for ENV in dev sit prod shared; do
  az storage container create \
    --subscription "$DEV_SUBSCRIPTION_ID" \
    --account-name "$TFSTATE_SA" \
    --name "tfstate-${ENV}" \
    --auth-mode login \
    --only-show-errors -o none 2>/dev/null || true
  echo "  Container: tfstate-${ENV}"
done

# =============================================================================
# 3. Resource Provider Registration
# =============================================================================
echo ""
echo "=== Registering resource providers ==="

for SUB_ID in "$DEV_SUBSCRIPTION_ID" "$SIT_SUBSCRIPTION_ID" "$PROD_SUBSCRIPTION_ID"; do
  az provider register --subscription "$SUB_ID" --namespace Microsoft.App --only-show-errors
  echo "  Microsoft.App registered in subscription ${SUB_ID:0:8}..."
done

# =============================================================================
# 4. Azure AD Application + Service Principal
# =============================================================================
echo ""
echo "=== Creating Azure AD application and service principal ==="

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query "appId" -o tsv --only-show-errors)
  echo "  Created app: $APP_ID"
else
  echo "  App already exists: $APP_ID"
fi

SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query "id" -o tsv 2>/dev/null || true)
if [ -z "$SP_OBJECT_ID" ]; then
  SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query "id" -o tsv --only-show-errors)
  echo "  Created SP: $SP_OBJECT_ID"
else
  echo "  SP already exists: $SP_OBJECT_ID"
fi

# =============================================================================
# 5. Federated Identity Credentials
# =============================================================================
echo ""
echo "=== Creating federated identity credentials ==="

APP_OBJECT_ID=$(az ad app show --id "$APP_ID" --query "id" -o tsv)

# Branch-based credentials
create_federated_credential "$APP_OBJECT_ID" \
  "github-zetdo-dev-branch" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/dev" \
  "GitHub Actions OIDC for dev (branch: refs/heads/dev)"

create_federated_credential "$APP_OBJECT_ID" \
  "github-zetdo-sit-branch" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/master" \
  "GitHub Actions OIDC for sit (branch: refs/heads/master)"

# Environment-based credentials
for ENV in dev sit prod shared; do
  create_federated_credential "$APP_OBJECT_ID" \
    "github-zetdo-${ENV}-env" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${ENV}" \
    "GitHub Actions OIDC for ${ENV} GitHub Environment"
done

# Pull request credential
create_federated_credential "$APP_OBJECT_ID" \
  "github-zetdo-pull-request" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request" \
  "GitHub Actions OIDC for pull request plans"

# =============================================================================
# 6. Role Assignments
# =============================================================================
echo ""
echo "=== Creating role assignments ==="

# Get resource IDs
DEV_RG_ID=$(az group show --subscription "$DEV_SUBSCRIPTION_ID" --name "$DEV_RG" --query id -o tsv)
SIT_RG_ID=$(az group show --subscription "$SIT_SUBSCRIPTION_ID" --name "$SIT_RG" --query id -o tsv)
PROD_RG_ID=$(az group show --subscription "$PROD_SUBSCRIPTION_ID" --name "$PROD_RG" --query id -o tsv)
SHARED_RG_ID=$(az group show --subscription "$DEV_SUBSCRIPTION_ID" --name "$SHARED_RG" --query id -o tsv)
TFSTATE_SA_ID=$(az storage account show --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$TFSTATE_RG" --name "$TFSTATE_SA" --query id -o tsv)

# Per-environment RG Contributor
assign_role "$DEV_RG_ID" "Contributor" "$SP_OBJECT_ID"
assign_role "$SIT_RG_ID" "Contributor" "$SP_OBJECT_ID"
assign_role "$PROD_RG_ID" "Contributor" "$SP_OBJECT_ID"

# Shared RG: User Access Administrator (for ACR role assignments from environments)
assign_role "$SHARED_RG_ID" "User Access Administrator" "$SP_OBJECT_ID"

# Shared RG: Contributor (for CI/CD to manage ACR)
assign_role "$SHARED_RG_ID" "Contributor" "$SP_OBJECT_ID"

# Shared RG: AcrPush (for app repo CI/CD to push images)
assign_role "$SHARED_RG_ID" "AcrPush" "$SP_OBJECT_ID"

# State storage: Storage Blob Data Contributor (for Terraform backend with OIDC)
assign_role "$TFSTATE_SA_ID" "Storage Blob Data Contributor" "$SP_OBJECT_ID"

# =============================================================================
# 7. Summary
# =============================================================================
TENANT_ID=$(az account show --query tenantId -o tsv)

echo ""
echo "=== Seed Complete ==="
echo ""
echo "GitHub Repository Secrets (repo-level):"
echo "  AZURE_CLIENT_ID              = $APP_ID"
echo "  AZURE_TENANT_ID              = $TENANT_ID"
echo "  AZURE_SHARED_SUBSCRIPTION_ID = $DEV_SUBSCRIPTION_ID"
echo "  ACR_LOGIN_SERVER             = crzetdo${LOCATION_SHORT}.azurecr.io"
echo ""
echo "GitHub Environment Secrets:"
echo "  dev:    AZURE_ENV_SUBSCRIPTION_ID = $DEV_SUBSCRIPTION_ID"
echo "  sit:    AZURE_ENV_SUBSCRIPTION_ID = $SIT_SUBSCRIPTION_ID"
echo "  prod:   AZURE_ENV_SUBSCRIPTION_ID = $PROD_SUBSCRIPTION_ID"
echo "  shared: AZURE_ENV_SUBSCRIPTION_ID = $DEV_SUBSCRIPTION_ID"
echo ""
echo "Next steps:"
echo "  1. Create GitHub Environment 'shared' with AZURE_ENV_SUBSCRIPTION_ID = $DEV_SUBSCRIPTION_ID"
echo "  2. Import ACR: cd environments/shared && terraform init"
echo "     terraform import 'azurerm_container_registry.acr' \\"
echo "       '/subscriptions/$DEV_SUBSCRIPTION_ID/resourceGroups/$SHARED_RG/providers/Microsoft.ContainerRegistry/registries/crzetdo${LOCATION_SHORT}'"
