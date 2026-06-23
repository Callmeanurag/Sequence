variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for AKS cluster"
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for the cluster API server FQDN"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version (e.g. 1.29)"
  default     = "1.29"
}

variable "sku_tier" {
  type        = string
  description = "AKS SKU tier: Free or Standard (Standard enables SLA)"
  default     = "Standard"
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be 'Free' or 'Standard'."
  }
}

variable "system_node_count" {
  type        = number
  description = "Number of system nodes (should match AZ count for HA)"
  default     = 3
}

variable "system_node_vm_size" {
  type        = string
  description = "VM size for system node pool"
  default     = "Standard_D4s_v3"
}

variable "system_subnet_id" {
  type        = string
  description = "Subnet ID for system node pool"
}

variable "user_node_vm_size" {
  type        = string
  description = "VM size for user node pool"
  default     = "Standard_D8s_v3"
}

variable "user_node_min_count" {
  type        = number
  description = "Minimum nodes in user pool"
  default     = 3
}

variable "user_node_max_count" {
  type        = number
  description = "Maximum nodes in user pool"
  default     = 10
}

variable "user_subnet_id" {
  type        = string
  description = "Subnet ID for user node pool"
}

variable "infra_node_vm_size" {
  type        = string
  description = "VM size for infra (platform) node pool"
  default     = "Standard_D4s_v3"
}

variable "infra_node_min_count" {
  type        = number
  description = "Minimum nodes in infra pool"
  default     = 2
}

variable "infra_node_max_count" {
  type        = number
  description = "Maximum nodes in infra pool"
  default     = 4
}

variable "infra_subnet_id" {
  type        = string
  description = "Subnet ID for infra node pool"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for node distribution"
  default     = ["1", "2", "3"]
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace resource ID for OMS agent"
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID for AcrPull role assignment to kubelet identity"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
