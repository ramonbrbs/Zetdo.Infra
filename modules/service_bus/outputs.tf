output "namespace_id" {
  description = "Service Bus namespace resource ID"
  value       = azurerm_servicebus_namespace.this.id
}

output "namespace_name" {
  description = "Service Bus namespace name"
  value       = azurerm_servicebus_namespace.this.name
}

output "namespace_fqdn" {
  description = "Fully qualified Service Bus namespace endpoint (for ServiceBus__fullyQualifiedNamespace)"
  value       = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "queue_name" {
  description = "Name of the reminders-due queue"
  value       = azurerm_servicebus_queue.reminders_due.name
}
