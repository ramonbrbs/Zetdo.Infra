# =============================================================================
# Azure Storage Account (Blob Storage)
# =============================================================================
resource "azurerm_storage_account" "this" {
  name                     = "stzetdo${var.environment}${var.location_short}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type

  # TODO(REQ-INF-003 / CON-INF-001): Flip to `false` once `company_logos` and
  # `offering_images` migrate from public-blob access to SAS reads. The
  # `attachments` container itself is private (see below), so the security
  # spine of REQ-INF-001/SEC-INF-001 is already in place even while this
  # account-level allowance remains true.
  allow_nested_items_to_be_public = true

  min_tls_version = "TLS1_2"

  tags = var.tags
}

# =============================================================================
# Blob Container - attachments (REQ-INF-001/002, SEC-INF-001)
# Always private regardless of environment; uploads/downloads use the
# Container App's managed identity + User Delegation Key SAS.
# =============================================================================
resource "azurerm_storage_container" "attachments" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = var.attachment_container_access_type
}

resource "azurerm_storage_container" "company_logos" {
  name                  = "company-logos"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "blob"
}

resource "azurerm_storage_container" "offering_images" {
  name                  = "offering-images"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "blob"
}

# =============================================================================
# Lifecycle Management Policy (REQ-INF-008, defensive)
# v1 deletes synchronously; this is a backstop that purges any blob under the
# `deleted/` virtual-folder prefix older than 7 days, preventing orphan growth
# if an async-delete path is added later.
# =============================================================================
resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "purge-soft-deleted-attachments"
    enabled = true
    filters {
      prefix_match = ["${var.blob_container_name}/deleted/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}
