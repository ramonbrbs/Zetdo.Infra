# =============================================================================
# Log Analytics Workspace (required by Container App Environment)
# =============================================================================
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

# =============================================================================
# Container App Environment
# =============================================================================
resource "azurerm_container_app_environment" "this" {
  name                       = "cae-zetdo-${var.environment}-${var.location_short}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  tags = var.tags
}

# =============================================================================
# User-Assigned Managed Identity (for ACR pull)
# =============================================================================
resource "azurerm_user_assigned_identity" "container_app" {
  name                = "id-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# NOTE: ACR Pull role assignment is created at the environment level (not here)
# to support cross-subscription scenarios where ACR lives in a different
# subscription than the Container App.

# =============================================================================
# Container App
# =============================================================================
resource "azurerm_container_app" "this" {
  name                         = "ca-zetdo-${var.environment}-${var.location_short}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server   = var.container_registry_login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  # -------- Bot Protection (Zet-19, REQ-010) --------
  # Pulls BotProtection--RecaptchaSecret from Key Vault using the user-assigned
  # managed identity granted "Key Vault Secrets User" at the vault scope. The
  # versionless ID makes the Container App pick up the latest secret version on
  # the next revision restart, satisfying CON-003 (rotation without code change).
  secret {
    name                = "botprotection--recaptchasecret"
    identity            = azurerm_user_assigned_identity.container_app.id
    key_vault_secret_id = var.recaptcha_secret_key_vault_id
  }

  # -------- Twilio Messaging (Zet-21, REQ-330) --------
  # Three Key Vault secrets proxied as Container App secrets. Same versionless-ID
  # pattern as bot protection (latest version pulled on revision restart). The
  # secrets are only declared when the env wires Twilio (defaults to empty).
  dynamic "secret" {
    for_each = var.twilio_account_sid_key_vault_id == "" ? [] : [1]
    content {
      name                = "twilio--accountsid"
      identity            = azurerm_user_assigned_identity.container_app.id
      key_vault_secret_id = var.twilio_account_sid_key_vault_id
    }
  }

  dynamic "secret" {
    for_each = var.twilio_auth_token_key_vault_id == "" ? [] : [1]
    content {
      name                = "twilio--authtoken"
      identity            = azurerm_user_assigned_identity.container_app.id
      key_vault_secret_id = var.twilio_auth_token_key_vault_id
    }
  }

  dynamic "secret" {
    for_each = var.twilio_messaging_service_sid_key_vault_id == "" ? [] : [1]
    content {
      name                = "twilio--messagingservicesid"
      identity            = azurerm_user_assigned_identity.container_app.id
      key_vault_secret_id = var.twilio_messaging_service_sid_key_vault_id
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "zetdo-app"
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.environment == "prod" ? "Production" : title(var.environment)
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.container_app.client_id
      }

      env {
        name  = "COSMOSDB_ENDPOINT"
        value = var.cosmosdb_endpoint
      }

      env {
        name  = "KeyVault__Url"
        value = var.key_vault_uri
      }

      env {
        name  = "AZURE_BLOB_ENDPOINT"
        value = var.blob_storage_endpoint
      }

      # -------- Attachments feature (REQ-INF-006) --------
      env {
        name  = "Attachments__StorageAccountName"
        value = var.attachments_storage_account_name
      }

      env {
        name  = "Attachments__ContainerName"
        value = var.attachments_container_name
      }

      env {
        name  = "Attachments__DownloadUrlTtlMinutes"
        value = tostring(var.attachments_download_url_ttl_minutes)
      }

      env {
        name  = "Attachments__MaxFileSizeBytes"
        value = tostring(var.attachments_max_file_size_bytes)
      }

      # -------- Attachment Management feature (REQ-INF-202) --------
      env {
        name  = "Attachments__UsageCacheSeconds"
        value = tostring(var.attachments_usage_cache_seconds)
      }

      env {
        name  = "Attachments__MaxFolderDepth"
        value = tostring(var.attachments_max_folder_depth)
      }

      # -------- Appointments feature (Zet-16, Calendar.Domain) --------
      env {
        name  = "AppointmentCosmosDb__DatabaseName"
        value = var.appointment_cosmosdb_database_name
      }

      env {
        name  = "AppointmentCosmosDb__ContainerName"
        value = var.appointment_cosmosdb_container_name
      }

      # -------- Bot Protection (Zet-19, REQ-010) --------
      # Hydrates Microsoft.Extensions.Configuration key BotProtection:RecaptchaSecret
      # from the Container App secret defined above (which proxies the Key Vault
      # secret BotProtection--RecaptchaSecret).
      env {
        name        = "BotProtection__RecaptchaSecret"
        secret_name = "botprotection--recaptchasecret"
      }

      # -------- Twilio Messaging (Zet-21, REQ-330) --------
      # Secret-backed env vars only emitted when the matching Key Vault secret
      # is wired by the environment (`var.*_key_vault_id != ""`).
      dynamic "env" {
        for_each = var.twilio_account_sid_key_vault_id == "" ? [] : [1]
        content {
          name        = "Twilio__AccountSid"
          secret_name = "twilio--accountsid"
        }
      }

      dynamic "env" {
        for_each = var.twilio_auth_token_key_vault_id == "" ? [] : [1]
        content {
          name        = "Twilio__AuthToken"
          secret_name = "twilio--authtoken"
        }
      }

      dynamic "env" {
        for_each = var.twilio_messaging_service_sid_key_vault_id == "" ? [] : [1]
        content {
          name        = "Twilio__MessagingServiceSid"
          secret_name = "twilio--messagingservicesid"
        }
      }

      # Plain Twilio env vars (REQ-330)
      env {
        name  = "Twilio__WhatsAppSenderE164"
        value = var.twilio_whatsapp_sender_e164
      }

      env {
        name  = "Twilio__StatusCallbackUrl"
        value = var.twilio_status_callback_url
      }

      # ContentTemplates as a single JSON setting (kept consistent with the
      # reminders Function App, where hyphenated env var names are rejected).
      # Parsed back into TwilioOptions.ContentTemplates in code.
      env {
        name = "Twilio__ContentTemplatesJson"
        value = jsonencode({
          "appointment-reminder" = {
            "en-US" = var.twilio_content_template_en
            "pt-BR" = var.twilio_content_template_ptbr
          }
        })
      }

      # -------- Service Bus (Zet-21, REQ-330, REQ-331) --------
      # Identity-based (CON-301) — no ConnectionString. Container App's UAMI
      # is granted Azure Service Bus Data Sender on the namespace.
      env {
        name  = "ServiceBus__fullyQualifiedNamespace"
        value = var.service_bus_namespace_fqdn
      }

      env {
        name  = "ServiceBus__ReminderQueueName"
        value = var.service_bus_reminder_queue_name
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }
}
