terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = "system"
    node_count                  = var.system_node_count
    vm_size                     = var.system_node_vm_size
    vnet_subnet_id              = var.system_subnet_id
    zones                       = var.availability_zones
    os_disk_size_gb             = 128
    os_disk_type                = "Ephemeral"
    only_critical_addons_enabled = true

    node_labels = {
      "role" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  monitor_metrics {}

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.user_node_vm_size
  vnet_subnet_id        = var.user_subnet_id
  zones                 = var.availability_zones
  os_disk_size_gb       = 128
  os_disk_type          = "Ephemeral"

  enable_auto_scaling = true
  min_count           = var.user_node_min_count
  max_count           = var.user_node_max_count

  node_labels = {
    "workload" = "game"
    "role"     = "user"
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "infra" {
  name                  = "infra"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.infra_node_vm_size
  vnet_subnet_id        = var.infra_subnet_id
  zones                 = var.availability_zones
  os_disk_size_gb       = 128

  enable_auto_scaling = true
  min_count           = var.infra_node_min_count
  max_count           = var.infra_node_max_count

  node_labels = {
    "workload" = "platform"
    "role"     = "infra"
  }

  node_taints = ["workload=platform:NoSchedule"]

  tags = var.tags
}

# Grant AKS kubelet identity ACR pull permission
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
