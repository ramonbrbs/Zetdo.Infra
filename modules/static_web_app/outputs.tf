output "static_web_app_id" {
  description = "Static Web App resource ID"
  value       = azurerm_static_web_app.this.id
}

output "static_web_app_name" {
  description = "Static Web App name"
  value       = azurerm_static_web_app.this.name
}

output "default_host_name" {
  description = "Default hostname of the Static Web App"
  value       = azurerm_static_web_app.this.default_host_name
}

output "default_url" {
  description = "Full HTTPS URL of the Static Web App"
  value       = "https://${azurerm_static_web_app.this.default_host_name}"
}

output "api_key" {
  description = "Deployment token for external CI/CD pipelines"
  value       = azurerm_static_web_app.this.api_key
  sensitive   = true
}

output "custom_domain_validation_token" {
  description = "Validation token to publish as a TXT record at the custom domain. Null when no custom domain configured."
  value       = try(azurerm_static_web_app_custom_domain.this[0].validation_token, null)
}
