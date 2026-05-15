variable "environment" {
  description = "Environment name (dev, sit, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "location_short" {
  description = "Short location name for resource naming"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "container_registry_login_server" {
  description = "Login server URL of the ACR"
  type        = string
}

variable "container_image" {
  description = "Initial container image (will be ignored after first deploy)"
  type        = string
  default     = "mcr.microsoft.com/k8s/demo/hello-app:latest"
}

variable "cpu" {
  description = "CPU allocation for the container"
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Memory allocation for the container"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 2
}

variable "target_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}

variable "cosmosdb_endpoint" {
  description = "CosmosDB account endpoint URL"
  type        = string
  default     = ""
}

variable "key_vault_uri" {
  description = "Key Vault URI"
  type        = string
  default     = ""
}

# -------- Bot Protection (Zet-19) --------
variable "recaptcha_secret_key_vault_id" {
  description = "Versionless Key Vault secret ID for BotProtection--RecaptchaSecret. The Container App pulls the latest version at revision restart."
  type        = string
  default     = ""
}

variable "blob_storage_endpoint" {
  description = "Primary blob storage endpoint URL"
  type        = string
  default     = ""
}

# -------- Attachments feature (REQ-INF-006) --------
variable "attachments_storage_account_name" {
  description = "Name of the storage account hosting the attachments container (e.g. stzetdodevweu)"
  type        = string
  default     = ""
}

variable "attachments_container_name" {
  description = "Name of the blob container that stores attachment binaries"
  type        = string
  default     = "attachments"
}

variable "attachments_download_url_ttl_minutes" {
  description = "TTL (minutes) for User Delegation Key SAS download URLs issued by the backend"
  type        = number
  default     = 5
}

variable "attachments_max_file_size_bytes" {
  description = "Maximum allowed attachment size in bytes (default 25 MiB)"
  type        = number
  default     = 26214400
}

# -------- Appointments feature (Zet-16, Calendar.Domain) --------
variable "appointment_cosmosdb_database_name" {
  description = "AppointmentCosmosDb:DatabaseName — Cosmos database hosting the Appointments container."
  type        = string
  default     = ""
}

variable "appointment_cosmosdb_container_name" {
  description = "AppointmentCosmosDb:ContainerName — Cosmos container holding Appointment aggregates."
  type        = string
  default     = ""
}

# -------- Attachment Management feature (REQ-INF-202, REQ-INF-203) --------
variable "attachments_usage_cache_seconds" {
  description = "Attachments:UsageCacheSeconds — TTL of the per-company storage-usage in-memory cache."
  type        = number
  default     = 30
}

variable "attachments_max_folder_depth" {
  description = "Attachments:MaxFolderDepth — maximum allowed folder nesting depth."
  type        = number
  default     = 8
}

# -------- Twilio Messaging (Zet-21, REQ-330) --------
# Versionless Key Vault secret IDs. Container App pulls latest version on each
# revision restart (CON-003 / AC-308). All three are optional so existing envs
# keep planning cleanly until messaging is enabled.
variable "twilio_account_sid_key_vault_id" {
  description = "Versionless Key Vault secret ID for twilio-account-sid"
  type        = string
  default     = ""
}

variable "twilio_auth_token_key_vault_id" {
  description = "Versionless Key Vault secret ID for twilio-auth-token"
  type        = string
  default     = ""
}

variable "twilio_messaging_service_sid_key_vault_id" {
  description = "Versionless Key Vault secret ID for twilio-messaging-service-sid"
  type        = string
  default     = ""
}

variable "twilio_whatsapp_sender_e164" {
  description = "WhatsApp sender phone number in E.164 (Twilio__WhatsAppSenderE164)"
  type        = string
  default     = ""
}

variable "twilio_status_callback_url" {
  description = "Twilio status callback URL (Twilio__StatusCallbackUrl). Points at the Web API."
  type        = string
  default     = ""
}

variable "twilio_content_template_en" {
  description = "Twilio Content Template SID for appointment-reminder en-US"
  type        = string
  default     = ""
}

variable "twilio_content_template_ptbr" {
  description = "Twilio Content Template SID for appointment-reminder pt-BR"
  type        = string
  default     = ""
}

# -------- Service Bus (Zet-21, REQ-330 / REQ-331) --------
variable "service_bus_namespace_fqdn" {
  description = "Service Bus fully qualified namespace (e.g. sb-zetdo-dev-weu.servicebus.windows.net). Identity-based — no connection string."
  type        = string
  default     = ""
}

variable "service_bus_reminder_queue_name" {
  description = "Name of the reminders queue (defaults to reminders-due)"
  type        = string
  default     = "reminders-due"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
