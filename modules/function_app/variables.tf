variable "name" {
  description = "Function App name (e.g. func-zetdo-reminders-dev-weu)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "storage_account_name" {
  description = "Functions runtime storage account name (≤24 chars, lowercase alphanumeric)"
  type        = string
}

variable "plan_sku" {
  description = "App Service Plan SKU (Y1 = Consumption; FC1 = Flex Consumption when ready)"
  type        = string
  default     = "Y1"
}

variable "dotnet_version" {
  description = "Function App .NET runtime version (e.g. 8.0, 9.0). Bump to 10.0 once azurerm provider supports it (hashicorp/terraform-provider-azurerm#30735)."
  type        = string
  default     = "8.0"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for Application Insights (typically shared with Container App)"
  type        = string
}

# -----------------------------------------------------------------------------
# Service Bus
# -----------------------------------------------------------------------------
variable "service_bus_namespace_fqdn" {
  description = "Service Bus FQDN (e.g. sb-zetdo-dev-weu.servicebus.windows.net) — identity-based, no connection string"
  type        = string
}

# -----------------------------------------------------------------------------
# Key Vault (refs are versionless Key Vault secret IDs)
# -----------------------------------------------------------------------------
variable "key_vault_id" {
  description = "Key Vault resource ID (for Key Vault Secrets User role assignment)"
  type        = string
}

variable "key_vault_secret_id_twilio_account_sid" {
  description = "Versionless Key Vault secret ID for twilio-account-sid"
  type        = string
}

variable "key_vault_secret_id_twilio_auth_token" {
  description = "Versionless Key Vault secret ID for twilio-auth-token"
  type        = string
}

variable "key_vault_secret_id_twilio_messaging_service_sid" {
  description = "Versionless Key Vault secret ID for twilio-messaging-service-sid"
  type        = string
}

# -----------------------------------------------------------------------------
# Twilio plain settings
# -----------------------------------------------------------------------------
variable "twilio_whatsapp_sender_e164" {
  description = "WhatsApp sender phone number in E.164 (e.g. +14155551234)"
  type        = string
}

variable "twilio_status_callback_url" {
  description = "Twilio status callback URL — must point at the Web API (Container App), not the Function App"
  type        = string
}

variable "twilio_content_template_en" {
  description = "Twilio Content Template SID for appointment-reminder en-US"
  type        = string
}

variable "twilio_content_template_ptbr" {
  description = "Twilio Content Template SID for appointment-reminder pt-BR"
  type        = string
}

# -----------------------------------------------------------------------------
# Cosmos DB
# -----------------------------------------------------------------------------
variable "cosmos_account_id" {
  description = "Cosmos DB account resource ID (for SQL role assignment scope)"
  type        = string
}

variable "cosmos_account_name" {
  description = "Cosmos DB account name (for SQL role assignment)"
  type        = string
}

variable "cosmos_account_endpoint" {
  description = "Cosmos DB account endpoint URL (https://...) for Cosmos__AccountEndpoint"
  type        = string
}

# -----------------------------------------------------------------------------
# Extras / tags
# -----------------------------------------------------------------------------
variable "app_settings_extra" {
  description = "Additional app settings to merge into the function app config"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all function-app resources"
  type        = map(string)
  default     = {}
}
