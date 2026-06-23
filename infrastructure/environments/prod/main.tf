locals {
  environment = "prod"
  location    = "eastus2"
  prefix      = "sequence-${local.environment}"

  common_tags = {
    Project     = "sequence-game"
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = "devops-learning"
    Owner       = "anurag-raj"
    Repository  = "github.com/Callmeanurag/Sequence"
  }
}

resource "azurerm_resource_group" "network" {
  name     = "rg-sequence-network-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "aks" {
  name     = "rg-sequence-aks-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "data" {
  name     = "rg-sequence-data-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-sequence-platform-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${local.prefix}"
  location            = local.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.common_tags
}

module "networking" {
  source              = "../../modules/networking"
  vnet_name           = "vnet-${local.prefix}"
  location            = local.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = ["10.0.0.0/8"]
  tags                = local.common_tags
}

module "acr" {
  source              = "../../modules/acr"
  acr_name            = "acrsequence${local.environment}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = local.location
  sku                 = var.acr_sku
  tags                = local.common_tags
}

module "aks" {
  source                     = "../../modules/aks"
  cluster_name               = "aks-${local.prefix}"
  location                   = local.location
  resource_group_name        = azurerm_resource_group.aks.name
  dns_prefix                 = "sequence-${local.environment}"
  kubernetes_version         = var.kubernetes_version
  sku_tier                   = var.aks_sku_tier
  system_node_vm_size        = var.system_node_vm_size
  system_node_count          = var.system_node_count
  system_subnet_id           = module.networking.aks_system_subnet_id
  user_node_vm_size          = var.user_node_vm_size
  user_node_min_count        = var.user_node_min_count
  user_node_max_count        = var.user_node_max_count
  user_subnet_id             = module.networking.aks_user_subnet_id
  infra_node_vm_size         = var.infra_node_vm_size
  infra_node_min_count       = var.infra_node_min_count
  infra_node_max_count       = var.infra_node_max_count
  infra_subnet_id            = module.networking.aks_infra_subnet_id
  availability_zones         = var.availability_zones
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  acr_id                     = module.acr.acr_id
  tags                       = local.common_tags
}

module "postgresql" {
  source                   = "../../modules/postgresql"
  server_name              = "psql-${local.prefix}"
  resource_group_name      = azurerm_resource_group.data.name
  location                 = local.location
  subnet_id                = module.networking.postgres_subnet_id
  private_dns_zone_id      = module.networking.postgres_private_dns_zone_id
  sku_name                 = var.postgres_sku
  storage_mb               = 262144
  storage_tier             = "P15"
  enable_high_availability = var.enable_postgres_ha
  backup_retention_days    = 35
  admin_username           = "pgadmin"
  admin_password           = var.postgres_admin_password
  databases                = ["auth_db", "game_db", "leaderboard_db", "analytics_db"]
  tags                     = local.common_tags
}

module "redis" {
  source                     = "../../modules/redis"
  redis_name                 = "redis-${local.prefix}"
  resource_group_name        = azurerm_resource_group.data.name
  location                   = local.location
  sku_name                   = var.redis_sku_name
  family                     = var.redis_family
  capacity                   = var.redis_capacity
  availability_zones         = ["1", "2", "3"]
  enable_private_endpoint    = true
  private_endpoint_subnet_id = module.networking.redis_subnet_id
  private_dns_zone_id        = module.networking.redis_private_dns_zone_id
  tags                       = local.common_tags
}

module "keyvault" {
  source                     = "../../modules/keyvault"
  keyvault_name              = "kv-sequence-${local.environment}"
  resource_group_name        = azurerm_resource_group.platform.name
  location                   = local.location
  private_endpoint_subnet_id = module.networking.aks_system_subnet_id
  tags                       = local.common_tags
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "postgres_fqdn" {
  value = module.postgresql.server_fqdn
}

output "redis_hostname" {
  value = module.redis.redis_hostname
}

output "keyvault_uri" {
  value = module.keyvault.keyvault_uri
}
