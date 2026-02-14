data "azurerm_client_config" "current" {}

# =============================================================================
# Azure Key Vault
# =============================================================================
resource "azurerm_key_vault" "this" {
  name                = "kv-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

# =============================================================================
# Key Vault Secrets
# =============================================================================
resource "azurerm_key_vault_secret" "firebase_credential_json" {
  name         = "User--Firebase--CredentialJson"
  value        = var.firebase_credential_json
  key_vault_id = azurerm_key_vault.this.id
}
