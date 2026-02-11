output "id" {
  description = "ACR resource ID"
  value       = data.azurerm_container_registry.this.id
}

output "login_server" {
  description = "ACR login server URL"
  value       = data.azurerm_container_registry.this.login_server
}

output "name" {
  description = "ACR name"
  value       = data.azurerm_container_registry.this.name
}
