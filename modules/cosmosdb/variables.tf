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

variable "free_tier_enabled" {
  description = "Enable CosmosDB free tier (only 1 per subscription)"
  type        = bool
  default     = false
}

variable "enable_serverless" {
  description = "Enable serverless capability (cannot be used with free tier)"
  type        = bool
  default     = true
}

variable "throughput" {
  description = "Database throughput in RU/s (only for provisioned mode, ignored for serverless)"
  type        = number
  default     = 400
}

variable "single_database_mode" {
  description = "When true, all containers share a single database (cost optimization for dev)"
  type        = bool
  default     = false
}

variable "messaging_max_throughput" {
  description = "Autoscale max RU/s for MessagingDB (provisioned-throughput accounts only — ignored for serverless). Azure autoscale floor is 1000 RU/s in increments of 1000 (scales 100–1000 RU/s)."
  type        = number
  default     = 1000

  validation {
    condition     = var.messaging_max_throughput >= 1000 && var.messaging_max_throughput % 1000 == 0
    error_message = "messaging_max_throughput must be >= 1000 and a multiple of 1000 (Azure Cosmos DB autoscale constraint)."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
