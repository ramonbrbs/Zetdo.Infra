variable "subscription_ids" {
  description = "Map of environment name to Azure subscription ID. Shared resources (state, ACR) go in the dev subscription."
  type        = map(string)

  validation {
    condition     = alltrue([for env in ["dev", "sit", "prod"] : contains(keys(var.subscription_ids), env)])
    error_message = "subscription_ids must contain keys: dev, sit, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "location_short" {
  description = "Short name for location used in resource naming (e.g., weu for westeurope)"
  type        = string
  default     = "weu"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (infrastructure repo)"
  type        = string
  default     = "zetdo-infra"
}
