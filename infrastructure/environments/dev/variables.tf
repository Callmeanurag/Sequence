variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "aks_sku_tier" {
  type    = string
  default = "Free"  # Free tier in dev saves $73/month
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_B2ms"  # Burstable for dev
}

variable "system_node_count" {
  type    = number
  default = 1  # Single node in dev (no HA needed)
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_B4ms"  # Burstable for dev
}

variable "user_node_min_count" {
  type    = number
  default = 1
}

variable "user_node_max_count" {
  type    = number
  default = 3
}

variable "infra_node_vm_size" {
  type    = string
  default = "Standard_B2ms"
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
  default = []  # No zone spreading in dev (fewer nodes)
}

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "postgres_sku" {
  type    = string
  default = "B_Standard_B2ms"  # Burstable for dev
}

variable "enable_postgres_ha" {
  type    = bool
  default = false  # No HA in dev
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
  # Set via: TF_VAR_postgres_admin_password env var or -var flag
  # Do NOT put the actual value in this file
}

variable "redis_sku_name" {
  type    = string
  default = "Basic"
}

variable "redis_family" {
  type    = string
  default = "C"
}

variable "redis_capacity" {
  type    = number
  default = 0  # C0 = 250MB, cheapest option
}
