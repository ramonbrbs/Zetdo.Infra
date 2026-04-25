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

variable "account_replication_type" {
  description = "Storage account replication type (LRS, GRS, ZRS, RAGRS)"
  type        = string
  default     = "LRS"
}

variable "blob_container_name" {
  description = "Name of the blob container for application uploads"
  type        = string
  default     = "attachments"
}

# REQ-INF-002: intentionally NOT exposed as a per-environment override.
# All environments must keep the attachments container private.
variable "attachment_container_access_type" {
  description = "Access type for the attachments container. Always 'private' — do not override per environment."
  type        = string
  default     = "private"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
