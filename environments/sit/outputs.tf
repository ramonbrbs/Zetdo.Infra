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
