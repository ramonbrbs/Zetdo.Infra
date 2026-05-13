output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "recaptcha_secret_versionless_id" {
  description = "Versionless ID of the BotProtection--RecaptchaSecret Key Vault secret. Used by Container App for `latest` Key Vault references."
  value       = azurerm_key_vault_secret.recaptcha_secret.versionless_id
}
