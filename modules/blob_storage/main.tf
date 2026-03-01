# =============================================================================
# Azure Storage Account (Blob Storage)
# =============================================================================
resource "azurerm_storage_account" "this" {
  name                     = "stzetdo${var.environment}${var.location_short}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type

  allow_nested_items_to_be_public = true

  min_tls_version = "TLS1_2"

  tags = var.tags
}

# =============================================================================
# Blob Container
# =============================================================================
resource "azurerm_storage_container" "attachments" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "blob"
}

resource "azurerm_storage_container" "company_logos" {
  name                  = "company-logos"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "blob"
}
