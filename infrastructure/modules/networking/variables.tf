variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "address_space" {
  type        = list(string)
  description = "VNet address space"
  default     = ["10.0.0.0/8"]
}

variable "aks_system_subnet_cidr" {
  type        = string
  description = "CIDR for AKS system node pool subnet"
  default     = "10.1.0.0/16"
}

variable "aks_user_subnet_cidr" {
  type        = string
  description = "CIDR for AKS user node pool subnet"
  default     = "10.2.0.0/16"
}

variable "aks_infra_subnet_cidr" {
  type        = string
  description = "CIDR for AKS infra node pool subnet"
  default     = "10.3.0.0/16"
}

variable "postgres_subnet_cidr" {
  type        = string
  description = "CIDR for PostgreSQL private endpoint subnet"
  default     = "10.4.0.0/24"
}

variable "redis_subnet_cidr" {
  type        = string
  description = "CIDR for Redis private endpoint subnet"
  default     = "10.5.0.0/24"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
