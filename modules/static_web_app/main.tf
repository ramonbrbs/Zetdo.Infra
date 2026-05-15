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

# =============================================================================
# Optional custom-domain binding
# =============================================================================
# Standard SKU is required for custom domains. For apex domains (e.g. zetdo.com)
# Azure requires a TXT validation token; for subdomains use cname-delegation.
# After plan/apply, read the `custom_domain_validation_token` output and create:
#   - TXT record at host "@" (or "_dnsauth.<domain>" for subdomains) with the token,
#   - ALIAS/ANAME/A record (apex) or CNAME (subdomain) pointing to default_host_name.
resource "azurerm_static_web_app_custom_domain" "this" {
  count             = var.custom_domain_name == "" ? 0 : 1
  static_web_app_id = azurerm_static_web_app.this.id
  domain_name       = var.custom_domain_name
  validation_type   = var.custom_domain_validation_type
}
