output "resource_group_name" {
  description = "Resource group name"
  value       = module.resource_group.name
}

output "static_web_app_name" {
  description = "Static Web App name"
  value       = module.static_web_app.static_web_app_name
}

output "static_web_app_url" {
  description = "Static Web App default HTTPS URL"
  value       = module.static_web_app.default_url
}

output "static_web_app_default_host_name" {
  description = "Static Web App default hostname (use as ALIAS/CNAME target)"
  value       = module.static_web_app.default_host_name
}

output "static_web_app_api_key" {
  description = "Deployment token for the landing-page repository GitHub Actions (sensitive). Copy into Zetdo.Landing repo secret AZURE_STATIC_WEB_APPS_API_TOKEN."
  value       = module.static_web_app.api_key
  sensitive   = true
}

output "custom_domain_validation_token" {
  description = "TXT record value to publish at the custom domain root for Azure to validate ownership."
  value       = module.static_web_app.custom_domain_validation_token
}
