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

variable "key_vault_purge_protection_enabled" {
  description = "Enable Key Vault purge protection (recommended for production)"
  type        = bool
  default     = false
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
