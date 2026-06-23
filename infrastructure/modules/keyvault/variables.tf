variable "keyvault_name" {
  type        = string
  description = "Key Vault name (must be globally unique, 3-24 chars)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for Key Vault private endpoint"
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "IP ranges allowed to access Key Vault (GitHub Actions runners)"
  default     = []
}

variable "secret_reader_principal_ids" {
  type        = list(string)
  description = "Object IDs of managed identities that need Key Vault Secrets User role"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
