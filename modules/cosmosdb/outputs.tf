output "account_id" {
  description = "CosmosDB account resource ID"
  value       = azurerm_cosmosdb_account.this.id
}

output "account_name" {
  description = "CosmosDB account name"
  value       = azurerm_cosmosdb_account.this.name
}

output "endpoint" {
  description = "CosmosDB account endpoint"
  value       = azurerm_cosmosdb_account.this.endpoint
}

output "primary_key" {
  description = "CosmosDB account primary key"
  value       = azurerm_cosmosdb_account.this.primary_key
  sensitive   = true
}

output "primary_sql_connection_string" {
  description = "CosmosDB primary SQL connection string"
  value       = azurerm_cosmosdb_account.this.primary_sql_connection_string
  sensitive   = true
}

output "database_name" {
  description = "CosmosDB SQL database name"
  value       = azurerm_cosmosdb_sql_database.this.name
}
