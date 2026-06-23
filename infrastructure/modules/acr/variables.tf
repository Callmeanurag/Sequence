variable "acr_name" {
  type        = string
  description = "ACR name (alphanumeric, globally unique)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "sku" {
  type        = string
  description = "ACR SKU: Basic, Standard, Premium"
  default     = "Premium"
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "IP ranges allowed to push images (GitHub Actions)"
  default     = []
}

variable "georeplications" {
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  description = "Geo-replication configuration (Premium only)"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
