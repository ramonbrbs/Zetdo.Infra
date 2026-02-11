terraform {
  backend "azurerm" {
    resource_group_name  = "rg-zetdo-tfstate"
    storage_account_name = "stzetdotfstateweu"
    container_name       = "tfstate-shared"
    key                  = "terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}
