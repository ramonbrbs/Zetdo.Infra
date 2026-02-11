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

variable "cosmosdb_primary_key" {
  description = "CosmosDB account primary key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
