variable "subscription_id" {
  description = "Azure subscription ID (dev subscription, where shared resources live)"
  type        = string
}

variable "location_short" {
  description = "Short name for location used in resource naming (e.g., weu for westeurope)"
  type        = string
  default     = "weu"
}
