variable "server_name" {
  type        = string
  description = "PostgreSQL Flexible Server name (must be globally unique)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for VNet integration (requires delegation)"
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone ID for PostgreSQL"
}

variable "admin_username" {
  type        = string
  description = "PostgreSQL administrator username"
  default     = "pgadmin"
}

variable "admin_password" {
  type        = string
  description = "PostgreSQL administrator password (store in Key Vault)"
  sensitive   = true
}

variable "sku_name" {
  type        = string
  description = "PostgreSQL SKU (e.g. GP_Standard_D4s_v3, B_Standard_B2ms)"
  default     = "GP_Standard_D4s_v3"
}

variable "storage_mb" {
  type        = number
  description = "Storage size in MB"
  default     = 262144  # 256 GB
}

variable "storage_tier" {
  type        = string
  description = "Storage tier (P4, P6, P10, P15, P20, P30, P40, P50, P60, P70, P80)"
  default     = "P15"
}

variable "enable_high_availability" {
  type        = bool
  description = "Enable zone-redundant high availability"
  default     = true
}

variable "backup_retention_days" {
  type        = number
  description = "Backup retention period in days (7-35)"
  default     = 35
}

variable "databases" {
  type        = list(string)
  description = "List of database names to create"
  default     = ["auth_db", "game_db", "leaderboard_db", "analytics_db"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
