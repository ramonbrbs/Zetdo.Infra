terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Default provider targets this environment's subscription
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Shared provider targets the dev subscription (where ACR and state live)
provider "azurerm" {
  alias = "shared"
  features {}
  subscription_id = var.shared_subscription_id
}

# =============================================================================
# Data Sources for Shared Resources (created by bootstrap)
# =============================================================================
module "resource_group" {
  source = "../../modules/resource_group"
  name   = "rg-zetdo-${var.environment}-${var.location_short}"
}

# =============================================================================
# CosmosDB
# =============================================================================
module "cosmosdb" {
  source = "../../modules/cosmosdb"

  environment         = var.environment
  location            = module.resource_group.location
  location_short      = var.location_short
  resource_group_name = module.resource_group.name
  free_tier_enabled   = var.cosmosdb_free_tier_enabled
  enable_serverless   = var.cosmosdb_enable_serverless
  throughput          = var.cosmosdb_throughput

  tags = local.tags
}

# =============================================================================
# Container App
# =============================================================================
module "container_app" {
  source = "../../modules/container_app"

  environment                     = var.environment
  location                        = module.resource_group.location
  location_short                  = var.location_short
  resource_group_name             = module.resource_group.name
  container_registry_login_server = var.acr_login_server
  container_image                 = var.container_image
  cpu                             = var.container_cpu
  memory                          = var.container_memory
  min_replicas                    = var.container_min_replicas
  max_replicas                    = var.container_max_replicas
  target_port                     = var.container_target_port
  log_retention_days              = var.log_retention_days
  cosmosdb_endpoint               = module.cosmosdb.endpoint
  cosmosdb_primary_key            = module.cosmosdb.primary_key

  tags = local.tags
}

# =============================================================================
# ACR Pull Role Assignment (cross-subscription via shared provider)
# =============================================================================
resource "azurerm_role_assignment" "container_app_acr_pull" {
  provider             = azurerm.shared
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.container_app.managed_identity_principal_id
}

# =============================================================================
# Local Values
# =============================================================================
locals {
  tags = {
    project     = "zetdo"
    environment = var.environment
    managed_by  = "terraform"
  }
}
