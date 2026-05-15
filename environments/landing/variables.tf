variable "subscription_id" {
  description = "Azure subscription ID for the landing environment (dev subscription — landing has no dedicated subscription)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "landing"
}

variable "location_short" {
  description = "Short location name for resource naming"
  type        = string
  default     = "weu"
}

variable "custom_domain_name" {
  description = "Custom apex domain bound to the Static Web App."
  type        = string
  default     = "zetdo.com"
}

variable "custom_domain_validation_type" {
  description = "Validation type for the custom domain. 'dns-txt-token' for apex, 'cname-delegation' for subdomains."
  type        = string
  default     = "dns-txt-token"
}
