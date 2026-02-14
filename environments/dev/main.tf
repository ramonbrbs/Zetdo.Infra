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
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

# Shared provider targets the dev subscription (where ACR and state live)
provider "azurerm" {
  alias = "shared"
  features {}
  subscription_id                 = var.shared_subscription_id
  resource_provider_registrations = "none"
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
# Key Vault
# =============================================================================
module "key_vault" {
  source = "../../modules/key_vault"

  environment         = var.environment
  location            = module.resource_group.location
  location_short      = var.location_short
  resource_group_name = module.resource_group.name

  purge_protection_enabled = var.key_vault_purge_protection_enabled

  firebase_credential_json = var.firebase_credential_json

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
  key_vault_uri                   = module.key_vault.key_vault_uri

  tags = local.tags
}

# =============================================================================
# Static Web App
# =============================================================================
module "static_web_app" {
  source = "../../modules/static_web_app"

  environment         = var.environment
  location            = module.resource_group.location
  location_short      = var.location_short
  resource_group_name = module.resource_group.name
  sku_tier            = var.static_web_app_sku_tier
  sku_size            = var.static_web_app_sku_size

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
# CosmosDB Data Contributor Role Assignment (managed identity access)
# =============================================================================
resource "azurerm_cosmosdb_sql_role_assignment" "container_app_data_contributor" {
  resource_group_name = module.resource_group.name
  account_name        = module.cosmosdb.account_name
  role_definition_id  = "${module.cosmosdb.account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = module.container_app.managed_identity_principal_id
  scope               = module.cosmosdb.account_id
}

# =============================================================================
# Key Vault Secrets User Role Assignment
# =============================================================================
resource "azurerm_role_assignment" "container_app_key_vault_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
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
