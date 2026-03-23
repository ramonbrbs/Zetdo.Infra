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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
