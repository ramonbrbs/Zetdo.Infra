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
  description = "CosmosDB SQL database name (UserDB or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.this[0].name
}

output "company_database_name" {
  description = "CosmosDB CompanyDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.company_db[0].name
}

output "customer_database_name" {
  description = "CosmosDB CustomerDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.customer_db[0].name
}

output "offering_database_name" {
  description = "CosmosDB OfferingDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.offering_db[0].name
}

output "sale_database_name" {
  description = "CosmosDB SaleDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.sale_db[0].name
}

output "calendar_database_name" {
  description = "CosmosDB CalendarDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.calendar_db[0].name
}

output "stock_database_name" {
  description = "CosmosDB StockDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.stock_db[0].name
}

output "attachment_database_name" {
  description = "CosmosDB AttachmentDB database name (or ZetdoDB in single database mode)"
  value       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.attachment_db[0].name
}

output "attachments_container_name" {
  description = "Cosmos container for attachment metadata"
  value       = azurerm_cosmosdb_sql_container.attachments.name
}
