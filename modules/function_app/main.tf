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
# Service Plan (Linux Consumption Y1 by default; configurable for Flex)
# =============================================================================
resource "azurerm_service_plan" "this" {
  name                = "asp-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.plan_sku

  tags = var.tags
}

# =============================================================================
# Linux Function App (dotnet-isolated on .NET 10)
# REQ-360..REQ-364 — system-assigned identity, https_only, Key Vault refs.
# =============================================================================
resource "azurerm_linux_function_app" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id               = azurerm_service_plan.this.id
  storage_account_name          = azurerm_storage_account.functions.name
  storage_uses_managed_identity = true

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
    application_insights_key               = azurerm_application_insights.this.instrumentation_key
    ftps_state                             = "Disabled"

    # NOTE: azurerm 4.x does not yet accept `dotnet_version = "10.0"` for the
    # isolated worker (tracked at hashicorp/terraform-provider-azurerm#30735).
    # The published .NET 10 package will still run on the Functions host — flip
    # this to "10.0" as soon as the provider adds it. 9.0 is the highest
    # validated value today.
    application_stack {
      dotnet_version              = var.dotnet_version
      use_dotnet_isolated_runtime = true
    }
  }

  app_settings = merge(
    {
      # Functions runtime
      FUNCTIONS_EXTENSION_VERSION = "~4"
      FUNCTIONS_WORKER_RUNTIME    = "dotnet-isolated"
      WEBSITE_RUN_FROM_PACKAGE    = "1"

      # Identity-based storage for the runtime (REQ-360, CON-301)
      "AzureWebJobsStorage__accountName" = azurerm_storage_account.functions.name

      # Service Bus (identity-based, no connection string — CON-301)
      "ServiceBus__fullyQualifiedNamespace" = var.service_bus_namespace_fqdn
      "ServiceBus__ReminderQueueName"       = "reminders-due"

      # Twilio credentials — Key Vault references (REQ-363)
      "Twilio__AccountSid"          = "@Microsoft.KeyVault(SecretUri=${var.key_vault_secret_id_twilio_account_sid})"
      "Twilio__AuthToken"           = "@Microsoft.KeyVault(SecretUri=${var.key_vault_secret_id_twilio_auth_token})"
      "Twilio__MessagingServiceSid" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_secret_id_twilio_messaging_service_sid})"

      # Twilio plain config
      "Twilio__WhatsAppSenderE164"                            = var.twilio_whatsapp_sender_e164
      "Twilio__StatusCallbackUrl"                             = var.twilio_status_callback_url
      "Twilio__ContentTemplates__appointment-reminder__en-US" = var.twilio_content_template_en
      "Twilio__ContentTemplates__appointment-reminder__pt-BR" = var.twilio_content_template_ptbr

      # Cosmos (managed-identity reads)
      "Cosmos__AccountEndpoint" = var.cosmos_account_endpoint
      "Cosmos__DatabaseName"    = "MessagingDB"
    },
    var.app_settings_extra
  )

  tags = var.tags

  lifecycle {
    # The package is published out-of-band by the function-messaging.yml workflow;
    # Terraform must not fight the deployment when WEBSITE_RUN_FROM_PACKAGE flips.
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# =============================================================================
# Role: Key Vault Secrets User on the vault → Function MI (REQ-364)
# =============================================================================
resource "azurerm_role_assignment" "function_key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
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
  principal_id        = azurerm_linux_function_app.this.identity[0].principal_id
  scope               = var.cosmos_account_id
}

# =============================================================================
# Roles: Storage data-plane for managed-identity AzureWebJobsStorage (REQ-364)
# Functions runtime needs Blob/Queue/Table Data Owner on its own storage account.
# =============================================================================
resource "azurerm_role_assignment" "function_storage_blob_owner" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_queue_owner" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_table_owner" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
}
