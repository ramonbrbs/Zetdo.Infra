output "container_app_id" {
  description = "Container App resource ID"
  value       = azurerm_container_app.this.id
}

output "container_app_name" {
  description = "Container App name"
  value       = azurerm_container_app.this.name
}

output "container_app_fqdn" {
  description = "Container App FQDN"
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "container_app_url" {
  description = "Full HTTPS URL of the Container App"
  value       = "https://${azurerm_container_app.this.ingress[0].fqdn}"
}

output "container_app_environment_id" {
  description = "Container App Environment resource ID"
  value       = azurerm_container_app_environment.this.id
}

output "managed_identity_id" {
  description = "User-assigned managed identity resource ID"
  value       = azurerm_user_assigned_identity.container_app.id
}

output "managed_identity_client_id" {
  description = "User-assigned managed identity client ID"
  value       = azurerm_user_assigned_identity.container_app.client_id
}

output "managed_identity_principal_id" {
  description = "User-assigned managed identity principal ID (for role assignments)"
  value       = azurerm_user_assigned_identity.container_app.principal_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID backing the Container App environment (shared with Function App App Insights)"
  value       = azurerm_log_analytics_workspace.this.id
}
