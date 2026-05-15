terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.40.0, < 5.0"
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

  environment          = var.environment
  location             = module.resource_group.location
  location_short       = var.location_short
  resource_group_name  = module.resource_group.name
  free_tier_enabled    = var.cosmosdb_free_tier_enabled
  enable_serverless    = var.cosmosdb_enable_serverless
  throughput           = var.cosmosdb_throughput
  single_database_mode = var.cosmosdb_single_database_mode

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

  firebase_credential_json     = var.firebase_credential_json
  password_hash                = var.password_hash
  recaptcha_secret             = var.recaptcha_secret
  twilio_account_sid           = var.twilio_account_sid
  twilio_auth_token            = var.twilio_auth_token
  twilio_messaging_service_sid = var.twilio_messaging_service_sid

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
  blob_storage_endpoint           = module.blob_storage.primary_blob_endpoint

  # Attachments feature (REQ-INF-006)
  attachments_storage_account_name = module.blob_storage.storage_account_name
  attachments_container_name       = module.blob_storage.attachments_container_name

  # Attachment Management feature (REQ-INF-204)
  attachments_usage_cache_seconds = var.attachments_usage_cache_seconds
  attachments_max_folder_depth    = var.attachments_max_folder_depth

  # Appointments feature (Zet-16, Calendar.Domain)
  appointment_cosmosdb_database_name  = module.cosmosdb.appointment_database_name
  appointment_cosmosdb_container_name = module.cosmosdb.appointments_container_name

  # Bot Protection (Zet-19) — Container App pulls latest version on revision restart.
  recaptcha_secret_key_vault_id = module.key_vault.recaptcha_secret_versionless_id

  # -------- Twilio Messaging (Zet-21) --------
  twilio_account_sid_key_vault_id           = module.key_vault.twilio_account_sid_versionless_id
  twilio_auth_token_key_vault_id            = module.key_vault.twilio_auth_token_versionless_id
  twilio_messaging_service_sid_key_vault_id = module.key_vault.twilio_messaging_service_sid_versionless_id
  twilio_whatsapp_sender_e164               = var.twilio_whatsapp_sender_e164
  twilio_status_callback_url                = local.twilio_status_callback_url
  twilio_content_template_en                = var.twilio_content_template_en
  twilio_content_template_ptbr              = var.twilio_content_template_ptbr

  # -------- Service Bus (Zet-21) --------
  service_bus_namespace_fqdn      = local.service_bus_namespace_fqdn
  service_bus_reminder_queue_name = "reminders-due"

  tags = local.tags
}

# =============================================================================
# Service Bus (Zet-21, REQ-301..REQ-303)
# =============================================================================
module "service_bus" {
  source = "../../modules/service_bus"

  name                  = "sb-zetdo-${var.environment}-${var.location_short}"
  location              = module.resource_group.location
  resource_group_name   = module.resource_group.name
  sku                   = "Standard"
  producer_principal_id = module.container_app.managed_identity_principal_id
  consumer_principal_id = module.function_app_messaging.principal_id

  tags = local.tags
}

# =============================================================================
# Function App — Twilio Messaging dispatcher (Zet-21, REQ-360..REQ-364)
# =============================================================================
module "function_app_messaging" {
  source = "../../modules/function_app"

  name                = "func-zetdo-reminders-${var.environment}-${var.location_short}"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  storage_account_name       = "stzetdofn${var.environment}${var.location_short}"
  log_analytics_workspace_id = module.container_app.log_analytics_workspace_id
  plan_sku                   = "FC1"

  service_bus_namespace_fqdn = local.service_bus_namespace_fqdn

  key_vault_id                                     = module.key_vault.key_vault_id
  key_vault_secret_id_twilio_account_sid           = module.key_vault.twilio_account_sid_versionless_id
  key_vault_secret_id_twilio_auth_token            = module.key_vault.twilio_auth_token_versionless_id
  key_vault_secret_id_twilio_messaging_service_sid = module.key_vault.twilio_messaging_service_sid_versionless_id

  twilio_whatsapp_sender_e164  = var.twilio_whatsapp_sender_e164
  twilio_status_callback_url   = local.twilio_status_callback_url
  twilio_content_template_en   = var.twilio_content_template_en
  twilio_content_template_ptbr = var.twilio_content_template_ptbr

  cosmos_account_id       = module.cosmosdb.account_id
  cosmos_account_name     = module.cosmosdb.account_name
  cosmos_account_endpoint = module.cosmosdb.endpoint

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
# Blob Storage
# =============================================================================
module "blob_storage" {
  source = "../../modules/blob_storage"

  environment              = var.environment
  location                 = module.resource_group.location
  location_short           = var.location_short
  resource_group_name      = module.resource_group.name
  account_replication_type = var.blob_storage_replication_type

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
# Blob Storage Data Contributor Role Assignment (managed identity upload access)
# =============================================================================
resource "azurerm_role_assignment" "container_app_blob_data_contributor" {
  scope                = module.blob_storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
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

  service_bus_namespace_fqdn = "sb-zetdo-${var.environment}-${var.location_short}.servicebus.windows.net"

  twilio_status_callback_url = "https://api.zetdo.com/api/v1/webhooks/twilio/status"
}
