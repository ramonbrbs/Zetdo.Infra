terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Landing environment lives entirely in the dev subscription (no dedicated landing
# subscription). Static Web App is the only resource provisioned here.
provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

# =============================================================================
# Resource Group (created by scripts/seed.sh)
# =============================================================================
module "resource_group" {
  source = "../../modules/resource_group"
  name   = "rg-zetdo-${var.environment}-${var.location_short}"
}

# =============================================================================
# Static Web App with custom domain (zetdo.com)
# =============================================================================
# Standard tier is required for custom domains. Apex domain (zetdo.com) uses
# dns-txt-token validation: after first apply, publish the TXT record from the
# `custom_domain_validation_token` output before the binding turns Ready.
module "static_web_app" {
  source = "../../modules/static_web_app"

  environment         = var.environment
  location            = module.resource_group.location
  location_short      = var.location_short
  resource_group_name = module.resource_group.name
  sku_tier            = "Standard"
  sku_size            = "Standard"

  custom_domain_name            = var.custom_domain_name
  custom_domain_validation_type = var.custom_domain_validation_type

  tags = local.tags
}

# =============================================================================
# Local Values
# =============================================================================
locals {
  tags = {
    project     = "zetdo"
    environment = var.environment
    managed_by  = "terraform"
  }
}
