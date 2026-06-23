output "keyvault_id" {
  value       = azurerm_key_vault.kv.id
  description = "Key Vault resource ID"
}

output "keyvault_uri" {
  value       = azurerm_key_vault.kv.vault_uri
  description = "Key Vault URI"
}

output "keyvault_name" {
  value       = azurerm_key_vault.kv.name
  description = "Key Vault name"
}
