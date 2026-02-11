variable "name" {
  description = "Name of the Azure Container Registry (created by bootstrap)"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the ACR"
  type        = string
}
