# =============================================================================
# Application Insights (Function App)
# Dedicated per function-app to keep reminders telemetry isolated. Reuses the
# log analytics workspace passed in from the env (shared with Container App).
# =============================================================================
resource "azurerm_application_insights" "this" {
  name                = "appi-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"

  tags = var.tags
}

# =============================================================================
# Storage Account (Functions runtime) — REQ-360
# Identity-based AzureWebJobsStorage; no key/connection-string is read.
# Name must be ≤24 chars, lowercase alphanumeric.
# =============================================================================
resource "azurerm_storage_account" "functions" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # AzureWebJobsStorage via managed identity (REQ-360).
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# =============================================================================
# Deployment package container (Flex Consumption)
# Flex Consumption deploys the app from a blob container (one-deploy), NOT via
# WEBSITE_RUN_FROM_PACKAGE. The Function MI authenticates with its
# SystemAssignedIdentity (Storage Blob Data Owner role below) — no key.
# =============================================================================
resource "azurerm_storage_container" "deployments" {
  name                  = "deployments"
  storage_account_id    = azurerm_storage_account.functions.id
  container_access_type = "private"
}

# =============================================================================
# Service Plan (Flex Consumption FC1 by default; Y1 = legacy Linux Consumption)
#
# Azure rejects an in-place SKU change Dynamic (Y1) -> FlexConsumption (FC1)
# on an existing server farm ("Cannot update ServerFarm SKU ... create a new
# ServerFarm"). The "-fc" name suffix makes the plan name (ForceNew) differ
# from the legacy Y1 farm, so Terraform replaces it instead of updating in
# place. create_before_destroy stands the new farm up before the old one is
# torn down (the old Function App is destroyed first via its dependency).
# =============================================================================
resource "azurerm_service_plan" "this" {
  name                = "asp-${var.name}-fc"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.plan_sku

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Flex Consumption Function App (dotnet-isolated on .NET 10)
# REQ-360..REQ-364 — system-assigned identity, https_only, Key Vault refs.
# Replaces the retired Linux Consumption (Y1) plan; deploys from a blob
# container via identity (no WEBSITE_RUN_FROM_PACKAGE, no storage key).
# =============================================================================
resource "azurerm_function_app_flex_consumption" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id = azurerm_service_plan.this.id

  # Identity-based deployment storage (REQ-360, CON-301): no key/SAS.
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.functions.primary_blob_endpoint}${azurerm_storage_container.deployments.name}"
  storage_authentication_type = "SystemAssignedIdentity"

  runtime_name    = "dotnet-isolated"
  runtime_version = var.dotnet_version

  instance_memory_in_mb  = var.instance_memory_in_mb
  maximum_instance_count = var.maximum_instance_count

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
    application_insights_key               = azurerm_application_insights.this.instrumentation_key
  }

  app_settings = merge(
    {
      # Identity-based runtime storage (REQ-360, CON-301)
      "AzureWebJobsStorage__accountName" = azurerm_storage_account.functions.name

      # Service Bus (identity-based, no connection string — CON-301)
      "ServiceBus__fullyQualifiedNamespace" = var.service_bus_namespace_fqdn
      "ServiceBus__ReminderQueueName"       = "reminders-due"

      # Twilio credentials — Key Vault references (REQ-363)
      "Twilio__AccountSid"          = "@Microsoft.KeyVault(SecretUri=${var.key_vault_secret_id_twilio_account_sid})"
      "Twilio__AuthToken"           = "@Microsoft.KeyVault(SecretUri=${var.key_vault_secret_id_twilio_auth_token})"
      "Twilio__MessagingServiceSid" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_secret_id_twilio_messaging_service_sid})"

      # Twilio plain config
      "Twilio__WhatsAppSenderE164" = var.twilio_whatsapp_sender_e164
      "Twilio__StatusCallbackUrl"  = var.twilio_status_callback_url
      # ContentTemplates as a single JSON setting: dict keys contain hyphens
      # ("appointment-reminder", "pt-BR") which are illegal in Function App
      # env var NAMES. Parsed back into TwilioOptions.ContentTemplates in code.
      "Twilio__ContentTemplatesJson" = jsonencode({
        "appointment-reminder" = {
          "en-US" = var.twilio_content_template_en
          "pt-BR" = var.twilio_content_template_ptbr
        }
      })

      # Cosmos (managed-identity reads)
      "Cosmos__AccountEndpoint" = var.cosmos_account_endpoint
      "Cosmos__DatabaseName"    = "MessagingDB"
    },
    var.app_settings_extra
  )

  tags = var.tags
}

# =============================================================================
# Role: Key Vault Secrets User on the vault → Function MI (REQ-364)
# =============================================================================
resource "azurerm_role_assignment" "function_key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

# =============================================================================
# Role: Cosmos DB Built-in Data Contributor (00000000-0000-0000-0000-000000000002)
# scoped at the Cosmos account so the dispatcher can READ Calendar/Customer/Company
# databases (cross-DB) and WRITE MessagingDB. Mirrors Container App pattern.
# REQ-364, INF-303.
# =============================================================================
resource "azurerm_cosmosdb_sql_role_assignment" "function_cosmos_data_contributor" {
  resource_group_name = var.resource_group_name
  account_name        = var.cosmos_account_name
  role_definition_id  = "${var.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_function_app_flex_consumption.this.identity[0].principal_id
  scope               = var.cosmos_account_id
}

# =============================================================================
# Roles: Storage data-plane for managed-identity AzureWebJobsStorage (REQ-364)
# Functions runtime needs Blob/Queue/Table Data Owner on its own storage account.
# =============================================================================
resource "azurerm_role_assignment" "function_storage_blob_owner" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_queue_owner" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_table_owner" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}
