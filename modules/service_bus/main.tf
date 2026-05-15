# =============================================================================
# Azure Service Bus Namespace (Zet-21, Twilio Messaging — REQ-301..REQ-303)
# Standard tier required for topics/subscriptions and unrestricted scheduled
# messages (CON-302). Local-auth disabled — both producer (Container App UAMI)
# and consumer (Function App system MI) authenticate via managed identity only
# (CON-301). No SAS authorization rules are created.
# =============================================================================
resource "azurerm_servicebus_namespace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  local_auth_enabled            = false
  public_network_access_enabled = true
  minimum_tls_version           = "1.2"

  tags = var.tags
}

# =============================================================================
# Service Bus Queue — `reminders-due` (Zet-21, REQ-301)
# Scheduled-message backbone for appointment reminders. Backend enqueues at the
# scheduled UTC time; Function App consumes and dispatches via Twilio.
# =============================================================================
resource "azurerm_servicebus_queue" "reminders_due" {
  name         = "reminders-due"
  namespace_id = azurerm_servicebus_namespace.this.id

  # PT30S lock + 5 deliveries gives the dispatcher up to ~2.5 min of retries.
  lock_duration                        = "PT30S"
  max_delivery_count                   = 5
  default_message_ttl                  = "P30D"
  partitioning_enabled                 = true
  dead_lettering_on_message_expiration = true
}

# =============================================================================
# Role Assignment — Producer (Container App UAMI) → Data Sender (REQ-303)
# =============================================================================
resource "azurerm_role_assignment" "producer_sender" {
  scope                = azurerm_servicebus_namespace.this.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = var.producer_principal_id
}

# =============================================================================
# Role Assignment — Consumer (Function App system MI) → Data Receiver (REQ-364)
# =============================================================================
resource "azurerm_role_assignment" "consumer_receiver" {
  scope                = azurerm_servicebus_namespace.this.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.consumer_principal_id
}
