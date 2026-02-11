output "storage_account_name" {
  description = "Storage account name for Terraform state backend"
  value       = azurerm_storage_account.tfstate.name
}

output "resource_group_name" {
  description = "Resource group containing state storage and shared resources"
  value       = azurerm_resource_group.tfstate.name
}

output "container_registry_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.acr.name
}

output "container_registry_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.acr.login_server
}

output "container_registry_id" {
  description = "ACR resource ID (needed for cross-subscription role assignments)"
  value       = azurerm_container_registry.acr.id
}

output "client_id" {
  description = "Application (client) ID for GitHub Actions OIDC"
  value       = azuread_application.github_actions.client_id
}

output "tenant_id" {
  description = "Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_ids" {
  description = "Subscription IDs per environment"
  value       = var.subscription_ids
}

output "shared_subscription_id" {
  description = "Dev subscription ID (where shared resources live: state, ACR)"
  value       = var.subscription_ids["dev"]
}

output "environment_resource_groups" {
  description = "Map of environment name to resource group name"
  value = {
    dev  = azurerm_resource_group.dev.name
    sit  = azurerm_resource_group.sit.name
    prod = azurerm_resource_group.prod.name
  }
}

output "github_secrets_summary" {
  description = "Values to configure as GitHub secrets"
  value = {
    repo_level = {
      AZURE_CLIENT_ID              = azuread_application.github_actions.client_id
      AZURE_TENANT_ID              = data.azurerm_client_config.current.tenant_id
      AZURE_SHARED_SUBSCRIPTION_ID = var.subscription_ids["dev"]
      ACR_LOGIN_SERVER             = azurerm_container_registry.acr.login_server
    }
    environment_level = {
      dev  = { AZURE_ENV_SUBSCRIPTION_ID = var.subscription_ids["dev"] }
      sit  = { AZURE_ENV_SUBSCRIPTION_ID = var.subscription_ids["sit"] }
      prod = { AZURE_ENV_SUBSCRIPTION_ID = var.subscription_ids["prod"] }
    }
  }
}
