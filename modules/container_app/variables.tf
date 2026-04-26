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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
