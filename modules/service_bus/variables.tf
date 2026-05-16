variable "name" {
  description = "Service Bus namespace name (e.g. sb-zetdo-dev-weu)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "sku" {
  description = "Service Bus SKU (Standard required for scheduled messages — CON-302)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.sku)
    error_message = "Service Bus SKU must be Standard or Premium (Basic does not support scheduled messages / topics)."
  }
}

variable "producer_principal_id" {
  description = "Principal ID of the producer identity (Container App UAMI). Granted Azure Service Bus Data Sender."
  type        = string
}

variable "consumer_principal_id" {
  description = "Principal ID of the Function App system MI. Granted Azure Service Bus Data Receiver (dispatch consume) and Data Sender (sweep promotes far-future reminders via ScheduleMessageAsync)."
  type        = string
}

variable "tags" {
  description = "Tags applied to all Service Bus resources"
  type        = map(string)
  default     = {}
}
