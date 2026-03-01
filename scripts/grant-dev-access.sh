#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Create (or reuse) a "Zetdo Developers" security group in Azure AD and assign
# it all the roles needed to run the Zetdo API locally against dev resources.
#
# Run once to set up the group + roles. Then just add developers to the group:
#   az ad group member add --group "zetdo-developers" --member-id <user-object-id>
#
# Usage:
#   export DEV_SUBSCRIPTION_ID="..."
#   ./scripts/grant-dev-access.sh                  # setup group + roles only
#   ./scripts/grant-dev-access.sh user@example.com  # also add a user to the group
# =============================================================================

DEV_SUBSCRIPTION_ID="${DEV_SUBSCRIPTION_ID:?Set DEV_SUBSCRIPTION_ID}"

LOCATION_SHORT="weu"
RG_NAME="rg-zetdo-dev-${LOCATION_SHORT}"
GROUP_DISPLAY_NAME="Zetdo Developers"
GROUP_MAIL_NICKNAME="zetdo-developers"

# =============================================================================
# 1. Create or get the security group
# =============================================================================
echo "=== Security group: $GROUP_DISPLAY_NAME ==="

GROUP_ID=$(az ad group list --display-name "$GROUP_DISPLAY_NAME" \
  --query "[0].id" -o tsv 2>/dev/null || true)

if [ -z "$GROUP_ID" ]; then
  GROUP_ID=$(az ad group create \
    --display-name "$GROUP_DISPLAY_NAME" \
    --mail-nickname "$GROUP_MAIL_NICKNAME" \
    --query id -o tsv --only-show-errors)
  echo "  Created group: $GROUP_ID"
  echo "  Waiting 30s for Azure AD propagation..."
  sleep 30
else
  echo "  Group already exists: $GROUP_ID"
fi

# =============================================================================
# 2. Resolve resource IDs
# =============================================================================
echo ""
echo "=== Resolving resource IDs ==="

COSMOSDB_NAME="cosmos-zetdo-dev-${LOCATION_SHORT}"
KV_NAME="kv-zetdo-dev-${LOCATION_SHORT}"
SA_NAME="stzetdodev${LOCATION_SHORT}"

COSMOSDB_ID=$(az cosmosdb show --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" --name "$COSMOSDB_NAME" --query id -o tsv)
echo "  CosmosDB: $COSMOSDB_NAME"

KV_ID=$(az keyvault show --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" --name "$KV_NAME" --query id -o tsv)
echo "  Key Vault: $KV_NAME"

SA_ID=$(az storage account show --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" --name "$SA_NAME" --query id -o tsv)
echo "  Storage: $SA_NAME"

# =============================================================================
# 3. Assign roles to the group
# =============================================================================

assign_role() {
  local SCOPE="$1"
  local ROLE="$2"

  EXISTING=$(az role assignment list --scope "$SCOPE" \
    --assignee "$GROUP_ID" --role "$ROLE" --query "[0].id" -o tsv 2>/dev/null || true)
  if [ -z "$EXISTING" ]; then
    az role assignment create --scope "$SCOPE" \
      --assignee-object-id "$GROUP_ID" \
      --assignee-principal-type Group \
      --role "$ROLE" --only-show-errors -o none
    echo "  Assigned: $ROLE on $(basename "$SCOPE")"
  else
    echo "  Already assigned: $ROLE on $(basename "$SCOPE")"
  fi
}

echo ""
echo "=== Assigning roles to group ==="

# Key Vault
echo ""
echo "--- Key Vault ---"
assign_role "$KV_ID" "Key Vault Secrets User"

# Blob Storage
echo ""
echo "--- Blob Storage ---"
assign_role "$SA_ID" "Storage Blob Data Contributor"

# CosmosDB - uses SQL data plane role (not ARM RBAC)
echo ""
echo "--- CosmosDB (SQL data plane role) ---"
COSMOS_ROLE_ID="${COSMOSDB_ID}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"

EXISTING_COSMOS=$(az cosmosdb sql role assignment list \
  --subscription "$DEV_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" \
  --account-name "$COSMOSDB_NAME" \
  --query "[?principalId=='${GROUP_ID}'].id" -o tsv 2>/dev/null || true)
if [ -z "$EXISTING_COSMOS" ]; then
  az cosmosdb sql role assignment create \
    --subscription "$DEV_SUBSCRIPTION_ID" \
    --resource-group "$RG_NAME" \
    --account-name "$COSMOSDB_NAME" \
    --role-definition-id "$COSMOS_ROLE_ID" \
    --principal-id "$GROUP_ID" \
    --scope "$COSMOSDB_ID" \
    --only-show-errors -o none
  echo "  Assigned: Cosmos DB Built-in Data Contributor"
else
  echo "  Already assigned: Cosmos DB Built-in Data Contributor"
fi

# =============================================================================
# 4. Optionally add a user to the group
# =============================================================================
if [ -n "${1:-}" ]; then
  echo ""
  echo "=== Adding user to group: $1 ==="

  USER_OBJECT_ID=$(az ad user show --id "$1" --query id -o tsv 2>/dev/null || true)
  if [ -z "$USER_OBJECT_ID" ]; then
    echo "  ERROR: Could not find user $1"
    exit 1
  fi

  IS_MEMBER=$(az ad group member check --group "$GROUP_ID" \
    --member-id "$USER_OBJECT_ID" --query value -o tsv 2>/dev/null || true)
  if [ "$IS_MEMBER" = "true" ]; then
    echo "  Already a member: $1"
  else
    az ad group member add --group "$GROUP_ID" \
      --member-id "$USER_OBJECT_ID" --only-show-errors
    echo "  Added: $1"
  fi
fi

# =============================================================================
# 5. Summary
# =============================================================================
echo ""
echo "=== Done! ==="
echo ""
echo "To add more developers, run:"
echo "  az ad group member add --group \"$GROUP_MAIL_NICKNAME\" --member-id <user-object-id>"
echo ""
echo "Required local env vars for developers:"
echo "  AZURE_BLOB_ENDPOINT=https://${SA_NAME}.blob.core.windows.net/"
echo "  COSMOSDB_ENDPOINT=https://${COSMOSDB_NAME}.documents.azure.com:443/"
echo "  KeyVault__Url=https://${KV_NAME}.vault.azure.net/"
