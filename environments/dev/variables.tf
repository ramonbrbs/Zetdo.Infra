variable "subscription_id" {
  description = "Azure subscription ID for this environment"
  type        = string
}

variable "shared_subscription_id" {
  description = "Dev subscription ID (where shared resources live: state storage, ACR)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location_short" {
  description = "Short location name for resource naming"
  type        = string
}

# ACR variables (shared, in dev subscription)
variable "acr_id" {
  description = "Resource ID of the shared Azure Container Registry"
  type        = string
}

variable "acr_login_server" {
  description = "Login server URL of the shared ACR"
  type        = string
}

# Container App variables
variable "container_image" {
  description = "Initial container image"
  type        = string
  default     = "mcr.microsoft.com/k8s/demo/hello-app:latest"
}

variable "container_cpu" {
  description = "Container CPU allocation"
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Container memory allocation"
  type        = string
  default     = "0.5Gi"
}

variable "container_min_replicas" {
  description = "Minimum replica count"
  type        = number
  default     = 0
}

variable "container_max_replicas" {
  description = "Maximum replica count"
  type        = number
  default     = 2
}

variable "container_target_port" {
  description = "Container listening port"
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

# CosmosDB variables
variable "cosmosdb_free_tier_enabled" {
  description = "Enable CosmosDB free tier"
  type        = bool
  default     = false
}

variable "cosmosdb_enable_serverless" {
  description = "Enable CosmosDB serverless mode"
  type        = bool
  default     = true
}

variable "cosmosdb_throughput" {
  description = "CosmosDB throughput (provisioned mode only)"
  type        = number
  default     = 400
}

variable "cosmosdb_single_database_mode" {
  description = "When true, all containers share a single database (cost optimization)"
  type        = bool
  default     = false
}

# Key Vault variables
variable "firebase_credential_json" {
  description = "Firebase credential JSON for Key Vault secret"
  type        = string
  sensitive   = true
}

variable "password_hash" {
  description = "Password hash for Key Vault secret"
  type        = string
  sensitive   = true
}

# Bot Protection (Zet-19)
variable "recaptcha_secret" {
  description = "Google reCAPTCHA v3 secret key for backend verification."
  type        = string
  sensitive   = true
}

# -------- Twilio Messaging (Zet-21) --------
variable "twilio_account_sid" {
  description = "Twilio Account SID — stored in Key Vault as twilio-account-sid (Zet-21)."
  type        = string
  sensitive   = true
}

variable "twilio_auth_token" {
  description = "Twilio Auth Token — stored in Key Vault as twilio-auth-token (Zet-21). Rotates independently."
  type        = string
  sensitive   = true
}

variable "twilio_messaging_service_sid" {
  description = "Twilio Messaging Service SID — stored in Key Vault as twilio-messaging-service-sid (Zet-21)."
  type        = string
  sensitive   = true
}

variable "twilio_whatsapp_sender_e164" {
  description = "WhatsApp sender phone number in E.164 (e.g. +14155551234)."
  type        = string
  default     = ""
}

variable "twilio_content_template_en" {
  description = "Twilio Content Template SID for appointment-reminder en-US."
  type        = string
  default     = ""
}

variable "twilio_content_template_ptbr" {
  description = "Twilio Content Template SID for appointment-reminder pt-BR."
  type        = string
  default     = ""
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable Key Vault purge protection (recommended for production)"
  type        = bool
  default     = false
}

# Blob Storage variables
variable "blob_storage_replication_type" {
  description = "Storage account replication type (LRS, GRS, ZRS, RAGRS)"
  type        = string
  default     = "LRS"
}

# Attachment Management variables (REQ-INF-203, REQ-INF-204)
variable "attachments_usage_cache_seconds" {
  description = "Per-company storage-usage in-memory cache TTL (seconds)."
  type        = number
  default     = 30
}

variable "attachments_max_folder_depth" {
  description = "Max attachment folder nesting depth."
  type        = number
  default     = 8
}

# Static Web App variables
variable "static_web_app_sku_tier" {
  description = "SKU tier for Static Web App (Free or Standard)"
  type        = string
  default     = "Free"
}

variable "static_web_app_sku_size" {
  description = "SKU size for Static Web App (Free or Standard)"
  type        = string
  default     = "Free"
}
