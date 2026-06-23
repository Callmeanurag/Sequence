variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "aks_sku_tier" {
  type    = string
  default = "Standard"
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "system_node_count" {
  type    = number
  default = 3
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "user_node_min_count" {
  type    = number
  default = 2
}

variable "user_node_max_count" {
  type    = number
  default = 6
}

variable "infra_node_vm_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "infra_node_min_count" {
  type    = number
  default = 1
}

variable "infra_node_max_count" {
  type    = number
  default = 2
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "postgres_sku" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "enable_postgres_ha" {
  type    = bool
  default = false
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
}

variable "redis_sku_name" {
  type    = string
  default = "Standard"
}

variable "redis_family" {
  type    = string
  default = "C"
}

variable "redis_capacity" {
  type    = number
  default = 1
}
