output "name" {
  description = "Resource group name"
  value       = data.azurerm_resource_group.this.name
}

output "location" {
  description = "Resource group location"
  value       = data.azurerm_resource_group.this.location
}

output "id" {
  description = "Resource group ID"
  value       = data.azurerm_resource_group.this.id
}
