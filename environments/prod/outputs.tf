output "container_app_url" {
  description = "Container App HTTPS URL"
  value       = module.container_app.container_app_url
}

output "container_app_name" {
  description = "Container App name"
  value       = module.container_app.container_app_name
}

output "cosmosdb_endpoint" {
  description = "CosmosDB endpoint"
  value       = module.cosmosdb.endpoint
}

output "cosmosdb_database_name" {
  description = "CosmosDB database name"
  value       = module.cosmosdb.database_name
}

output "resource_group_name" {
  description = "Resource group name"
  value       = module.resource_group.name
}

output "static_web_app_url" {
  description = "Static Web App HTTPS URL"
  value       = module.static_web_app.default_url
}

output "static_web_app_name" {
  description = "Static Web App name"
  value       = module.static_web_app.static_web_app_name
}

output "static_web_app_api_key" {
  description = "Static Web App deployment token (for external CI/CD)"
  value       = module.static_web_app.api_key
  sensitive   = true
}
