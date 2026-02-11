terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Provider targets the dev subscription (where shared resources live)
provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

# =============================================================================
# Data source for the shared resource group (created by seed script)
# =============================================================================
data "azurerm_resource_group" "shared" {
  name = "rg-zetdo-shared-${var.location_short}"
}

# =============================================================================
# Azure Container Registry (shared across all environments)
# =============================================================================
resource "azurerm_container_registry" "acr" {
  name                = "crzetdo${var.location_short}"
  resource_group_name = data.azurerm_resource_group.shared.name
  location            = data.azurerm_resource_group.shared.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    project    = "zetdo"
    managed_by = "terraform"
  }
}
