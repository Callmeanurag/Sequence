output "server_id" {
  value       = azurerm_postgresql_flexible_server.postgres.id
  description = "PostgreSQL Flexible Server resource ID"
}

output "server_fqdn" {
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
  description = "Fully qualified domain name for the PostgreSQL server"
}

output "server_name" {
  value       = azurerm_postgresql_flexible_server.postgres.name
  description = "PostgreSQL server name"
}
