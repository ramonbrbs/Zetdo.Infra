# =============================================================================
# Azure Static Web App
# =============================================================================
resource "azurerm_static_web_app" "this" {
  name                = "stapp-zetdo-${var.environment}-${var.location_short}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.sku_tier
  sku_size            = var.sku_size

  tags = var.tags
}
