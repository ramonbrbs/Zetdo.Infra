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

# Deprecated: use managed identity authentication instead of key-based access
output "primary_key" {
  description = "CosmosDB account primary key (deprecated: use managed identity)"
  value       = azurerm_cosmosdb_account.this.primary_key
  sensitive   = true
}

# Deprecated: use managed identity authentication instead of connection strings
output "primary_sql_connection_string" {
  description = "CosmosDB primary SQL connection string (deprecated: use managed identity)"
  value       = azurerm_cosmosdb_account.this.primary_sql_connection_string
  sensitive   = true
}

output "database_name" {
  description = "CosmosDB SQL database name"
  value       = azurerm_cosmosdb_sql_database.this.name
}

output "company_database_name" {
  description = "CosmosDB CompanyDB database name"
  value       = azurerm_cosmosdb_sql_database.company_db.name
}

output "customer_database_name" {
  description = "CosmosDB CustomerDB database name"
  value       = azurerm_cosmosdb_sql_database.customer_db.name
}
