output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "VNet resource ID"
}

output "aks_system_subnet_id" {
  value       = azurerm_subnet.aks_system.id
  description = "System node pool subnet ID"
}

output "aks_user_subnet_id" {
  value       = azurerm_subnet.aks_user.id
  description = "User node pool subnet ID"
}

output "aks_infra_subnet_id" {
  value       = azurerm_subnet.aks_infra.id
  description = "Infra node pool subnet ID"
}

output "postgres_subnet_id" {
  value       = azurerm_subnet.postgres.id
  description = "PostgreSQL subnet ID"
}

output "redis_subnet_id" {
  value       = azurerm_subnet.redis.id
  description = "Redis subnet ID"
}

output "postgres_private_dns_zone_id" {
  value       = azurerm_private_dns_zone.postgres.id
  description = "PostgreSQL private DNS zone ID"
}

output "redis_private_dns_zone_id" {
  value       = azurerm_private_dns_zone.redis.id
  description = "Redis private DNS zone ID"
}
