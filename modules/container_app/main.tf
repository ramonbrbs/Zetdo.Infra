# =============================================================================
# Log Analytics Workspace (required by Container App Environment)
# =============================================================================
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

# =============================================================================
# Container App Environment
# =============================================================================
resource "azurerm_container_app_environment" "this" {
  name                       = "cae-zetdo-${var.environment}-${var.location_short}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  tags = var.tags
}

# =============================================================================
# User-Assigned Managed Identity (for ACR pull)
# =============================================================================
resource "azurerm_user_assigned_identity" "container_app" {
  name                = "id-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# NOTE: ACR Pull role assignment is created at the environment level (not here)
# to support cross-subscription scenarios where ACR lives in a different
# subscription than the Container App.

# =============================================================================
# Container App
# =============================================================================
resource "azurerm_container_app" "this" {
  name                         = "ca-zetdo-${var.environment}-${var.location_short}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server   = var.container_registry_login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "zetdo-app"
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.environment == "prod" ? "Production" : title(var.environment)
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.container_app.client_id
      }

      env {
        name  = "COSMOSDB_ENDPOINT"
        value = var.cosmosdb_endpoint
      }

      env {
        name  = "KeyVault__Url"
        value = var.key_vault_uri
      }

      env {
        name  = "AZURE_BLOB_ENDPOINT"
        value = var.blob_storage_endpoint
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }
}
