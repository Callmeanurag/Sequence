output "redis_id" {
  value       = azurerm_redis_cache.redis.id
  description = "Redis cache resource ID"
}

output "redis_hostname" {
  value       = azurerm_redis_cache.redis.hostname
  description = "Redis hostname"
}

output "redis_ssl_port" {
  value       = azurerm_redis_cache.redis.ssl_port
  description = "Redis SSL port (6380)"
}

output "redis_primary_access_key" {
  value       = azurerm_redis_cache.redis.primary_access_key
  description = "Redis primary access key"
  sensitive   = true
}
