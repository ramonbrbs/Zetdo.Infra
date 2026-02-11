terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

# =============================================================================
# Providers - one per subscription (default = dev / shared resources)
# =============================================================================
provider "azurerm" {
  features {}
  subscription_id = var.subscription_ids["dev"]
}

provider "azurerm" {
  alias = "sit"
  features {}
  subscription_id = var.subscription_ids["sit"]
}

provider "azurerm" {
  alias = "prod"
  features {}
  subscription_id = var.subscription_ids["prod"]
}

provider "azuread" {}

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# =============================================================================
# Resource Group for Terraform State (dev subscription)
# =============================================================================
resource "azurerm_resource_group" "tfstate" {
  name     = "rg-zetdo-tfstate"
  location = var.location

  tags = {
    project    = "zetdo"
    managed_by = "terraform-bootstrap"
    purpose    = "terraform-state"
  }
}

# =============================================================================
# Resource Group for Shared Resources (dev subscription)
# =============================================================================
resource "azurerm_resource_group" "shared" {
  name     = "rg-zetdo-shared-${var.location_short}"
  location = var.location

  tags = {
    project    = "zetdo"
    managed_by = "terraform-bootstrap"
    purpose    = "shared-resources"
  }
}

# =============================================================================
# Storage Account for Terraform State (dev subscription)
# =============================================================================
resource "azurerm_storage_account" "tfstate" {
  name                            = "stzetdotfstate${var.location_short}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }

  tags = {
    project    = "zetdo"
    managed_by = "terraform-bootstrap"
  }
}

# Storage containers - one per environment
resource "azurerm_storage_container" "tfstate" {
  for_each              = toset(["dev", "sit", "prod"])
  name                  = "tfstate-${each.key}"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# =============================================================================
# Resource Provider Registrations (per subscription)
# Microsoft.App is not in the AzureRM "core" set, so it must be registered
# explicitly. The environment providers use resource_provider_registrations =
# "none" (SP only has RG-level Contributor), so we register it here instead.
# =============================================================================
resource "azurerm_resource_provider_registration" "dev_container_apps" {
  name = "Microsoft.App"
}

resource "azurerm_resource_provider_registration" "sit_container_apps" {
  provider = azurerm.sit
  name     = "Microsoft.App"
}

resource "azurerm_resource_provider_registration" "prod_container_apps" {
  provider = azurerm.prod
  name     = "Microsoft.App"
}

# =============================================================================
# Environment Resource Groups (each in its own subscription)
# =============================================================================
resource "azurerm_resource_group" "dev" {
  name     = "rg-zetdo-dev-${var.location_short}"
  location = var.location

  tags = {
    project     = "zetdo"
    environment = "dev"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "sit" {
  provider = azurerm.sit
  name     = "rg-zetdo-sit-${var.location_short}"
  location = var.location

  tags = {
    project     = "zetdo"
    environment = "sit"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "prod" {
  provider = azurerm.prod
  name     = "rg-zetdo-prod-${var.location_short}"
  location = var.location

  tags = {
    project     = "zetdo"
    environment = "prod"
    managed_by  = "terraform"
  }
}

# =============================================================================
# Azure Container Registry (shared, in dev subscription)
# =============================================================================
resource "azurerm_container_registry" "acr" {
  name                = "crzetdo${var.location_short}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    project    = "zetdo"
    managed_by = "terraform-bootstrap"
  }
}

# =============================================================================
# Azure AD Application + Service Principal for GitHub Actions
# =============================================================================
resource "azuread_application" "github_actions" {
  display_name = "zetdo-github-actions"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# =============================================================================
# Federated Identity Credentials for OIDC
# =============================================================================

# Branch-based credentials
resource "azuread_application_federated_identity_credential" "branch" {
  for_each = {
    dev = "refs/heads/dev"
    sit = "refs/heads/master"
  }

  application_id = azuread_application.github_actions.id
  display_name   = "github-zetdo-${each.key}-branch"
  description    = "GitHub Actions OIDC for ${each.key} environment (branch: ${each.value})"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:${each.value}"
}

# Environment-based credentials (primary mechanism for GitHub Environments)
resource "azuread_application_federated_identity_credential" "environment" {
  for_each = toset(["dev", "sit", "prod"])

  application_id = azuread_application.github_actions.id
  display_name   = "github-zetdo-${each.key}-env"
  description    = "GitHub Actions OIDC for ${each.key} GitHub Environment"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:${each.key}"
}

# Pull request credential (for plan on PRs)
resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-zetdo-pull-request"
  description    = "GitHub Actions OIDC for pull request plans"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

# =============================================================================
# Role Assignments - Per subscription
# =============================================================================

# -- Dev subscription --
resource "azurerm_role_assignment" "dev_contributor" {
  scope                = azurerm_resource_group.dev.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# -- Sit subscription --
resource "azurerm_role_assignment" "sit_contributor" {
  provider             = azurerm.sit
  scope                = azurerm_resource_group.sit.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# -- Prod subscription --
resource "azurerm_role_assignment" "prod_contributor" {
  provider             = azurerm.prod
  scope                = azurerm_resource_group.prod.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# -- Shared resources (dev subscription) --

# User Access Administrator on shared RG (allows environment Terraform to create
# ACR role assignments for Container App managed identities)
resource "azurerm_role_assignment" "shared_uaa" {
  scope                = azurerm_resource_group.shared.id
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# AcrPush on the container registry (for app repo CI/CD to push images)
resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Storage Blob Data Contributor on state storage (for Terraform backend with OIDC)
resource "azurerm_role_assignment" "tfstate_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}
