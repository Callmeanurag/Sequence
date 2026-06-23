resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = var.server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  delegated_subnet_id    = var.subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  zone                   = "1"

  storage_mb   = var.storage_mb
  storage_tier = var.storage_tier
  sku_name     = var.sku_name

  dynamic "high_availability" {
    for_each = var.enable_high_availability ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = false

  maintenance_window {
    day_of_week  = 0  # Sunday
    start_hour   = 3  # 3 AM UTC
    start_minute = 0
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      administrator_password,
      zone,
      high_availability[0].standby_availability_zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "databases" {
  for_each  = toset(var.databases)
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  value     = "on"
}
