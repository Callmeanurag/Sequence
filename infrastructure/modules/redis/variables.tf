variable "redis_name" {
  type        = string
  description = "Redis cache name (must be globally unique)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "sku_name" {
  type        = string
  description = "Redis SKU: Basic, Standard, or Premium"
  default     = "Premium"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_name)
    error_message = "sku_name must be Basic, Standard, or Premium."
  }
}

variable "family" {
  type        = string
  description = "Redis family: C (Basic/Standard) or P (Premium)"
  default     = "P"
}

variable "capacity" {
  type        = number
  description = "Redis capacity (0-6 for C family, 1-5 for P family)"
  default     = 1
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones (Premium only)"
  default     = ["1", "2", "3"]
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Enable private endpoint for Redis"
  default     = true
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for private endpoint"
  default     = ""
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone ID for Redis"
  default     = ""
}

variable "backup_storage_connection_string" {
  type        = string
  description = "Storage connection string for RDB backups (Premium only)"
  sensitive   = true
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
