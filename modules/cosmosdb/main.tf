# =============================================================================
# CosmosDB Account
# =============================================================================
resource "azurerm_cosmosdb_account" "this" {
  name                = "cosmos-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  free_tier_enabled = var.free_tier_enabled

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # Serverless capability (for sit/prod - cheapest pay-per-use)
  dynamic "capabilities" {
    for_each = var.enable_serverless ? [1] : []
    content {
      name = "EnableServerless"
    }
  }

  public_network_access_enabled         = true
  network_acl_bypass_for_azure_services = true
  local_authentication_disabled         = false

  tags = var.tags
}

# =============================================================================
# CosmosDB SQL Database
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "this" {
  name                = "UserDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  # Do NOT set throughput when using serverless - it will error.
  # For free tier (provisioned), use 400 RU/s (minimum).
  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "user_profiles" {
  name                = "UserProfiles"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/id"]
}
