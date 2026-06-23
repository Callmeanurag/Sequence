output "acr_id" {
  value       = azurerm_container_registry.acr.id
  description = "ACR resource ID"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server FQDN"
}

output "acr_name" {
  value       = azurerm_container_registry.acr.name
  description = "ACR name"
}
