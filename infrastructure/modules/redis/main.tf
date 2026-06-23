resource "azurerm_redis_cache" "redis" {
  name                = var.redis_name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    enable_authentication         = true
    maxmemory_reserved            = var.sku_name == "Premium" ? 2 : 10
    maxmemory_delta               = var.sku_name == "Premium" ? 2 : 10
    maxmemory_policy              = "allkeys-lru"
    rdb_backup_enabled            = var.sku_name == "Premium" ? true : false
    rdb_backup_frequency          = var.sku_name == "Premium" ? 60 : null
    rdb_storage_connection_string = var.sku_name == "Premium" ? var.backup_storage_connection_string : null
  }

  zones = var.sku_name == "Premium" ? var.availability_zones : null

  tags = var.tags
}

resource "azurerm_private_endpoint" "redis" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.redis_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.redis_name}-psc"
    private_connection_resource_id = azurerm_redis_cache.redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}
