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

variable "sku_tier" {
  description = "SKU tier for the Static Web App (Free or Standard)"
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be either 'Free' or 'Standard'."
  }
}

variable "sku_size" {
  description = "SKU size for the Static Web App (must match sku_tier)"
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_size)
    error_message = "sku_size must be either 'Free' or 'Standard'."
  }
}

variable "custom_domain_name" {
  description = "Optional custom domain to bind to the Static Web App (e.g. zetdo.com). Empty string disables the binding."
  type        = string
  default     = ""
}

variable "custom_domain_validation_type" {
  description = "Validation type for the custom domain. Use 'dns-txt-token' for apex domains and 'cname-delegation' for subdomains."
  type        = string
  default     = "dns-txt-token"

  validation {
    condition     = contains(["dns-txt-token", "cname-delegation"], var.custom_domain_validation_type)
    error_message = "custom_domain_validation_type must be either 'dns-txt-token' or 'cname-delegation'."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
