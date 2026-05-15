output "function_app_id" {
  description = "Function App resource ID"
  value       = azurerm_linux_function_app.this.id
}

output "function_app_name" {
  description = "Function App name"
  value       = azurerm_linux_function_app.this.name
}

output "principal_id" {
  description = "System-assigned managed identity principal ID of the Function App"
  value       = azurerm_linux_function_app.this.identity[0].principal_id
}

output "default_hostname" {
  description = "Default Function App hostname (e.g. <name>.azurewebsites.net)"
  value       = azurerm_linux_function_app.this.default_hostname
}

output "storage_account_id" {
  description = "Resource ID of the Functions runtime storage account"
  value       = azurerm_storage_account.functions.id
}

output "storage_account_name" {
  description = "Name of the Functions runtime storage account"
  value       = azurerm_storage_account.functions.name
}

output "application_insights_connection_string" {
  description = "App Insights connection string for the Function App"
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
