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

variable "soft_delete_retention_days" {
  description = "Number of days to retain deleted key vault (7-90)"
  type        = number
  default     = 90
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (recommended for production)"
  type        = bool
  default     = false
}

variable "firebase_credential_json" {
  description = "Firebase credential JSON value for Key Vault secret"
  type        = string
  sensitive   = true
}

variable "password_hash" {
  description = "Password hash value for Key Vault secret"
  type        = string
  sensitive   = true
}

variable "recaptcha_secret" {
  description = "Google reCAPTCHA v3 secret key for backend verification."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
