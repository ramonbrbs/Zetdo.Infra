output "storage_account_id" {
  description = "Storage account resource ID"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob service endpoint"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "blob_container_name" {
  description = "Name of the blob container"
  value       = azurerm_storage_container.attachments.name
}

output "attachments_container_name" {
  description = "Name of the attachments blob container"
  value       = azurerm_storage_container.attachments.name
}
