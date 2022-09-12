resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku_tier            = "Paid"
  kubernetes_version  = var.kubernetes_version

  dns_prefix = "${var.aks_cluster_name}-aks"  
  # private_cluster_enabled = true
  # node_resource_group = "aks-mc-${data.azurerm_resource_group.rg.name}"

  default_node_pool {
    name                 = "default"
    type                 = "VirtualMachineScaleSets"
    vm_size              = "Standard_D2as_v4"
    zones   = ["1", "2", "3"]
    enable_auto_scaling  = true
    node_count           = 2
    max_count            = 3
    min_count            = 2
    max_pods              = 100
    orchestrator_version = var.kubernetes_version
    vnet_subnet_id       = data.azurerm_subnet.aks.id

    only_critical_addons_enabled = true
    # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#only_critical_addons_enabled
    # https://docs.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli
  }

  # linux_profile {
  #   admin_username = "suren"
  #   ssh_key {
  #     key_data = file("../files/id_rsa.pub")
  #   }
  # }

  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.2.0.0/24"
  }

  # https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-control-plane-mi
  identity {
    type                      = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.aks_controlplane_ua_mi.id]
  }

  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster (see identity)
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity
  kubelet_identity {
    user_assigned_identity_id = data.azurerm_user_assigned_identity.aks_kubelet_ua_mi.id
    client_id                 = data.azurerm_user_assigned_identity.aks_kubelet_ua_mi.client_id
    object_id                 = data.azurerm_user_assigned_identity.aks_kubelet_ua_mi.principal_id
  }

  azure_policy_enabled = true

  oms_agent {
      log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
    secret_rotation_interval = "5m"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "common" {
  name                  = "common"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  enable_auto_scaling   = false
  vm_size               = "Standard_D2as_v4"
  node_count            = 6
  # max_count             = 5
  # min_count             = 2
  max_pods              = 250
  orchestrator_version  = var.kubernetes_version
  zones    = [1, 2, 3]
  mode                  = "User"
  node_labels           = { workloads = "common" }
  vnet_subnet_id        = data.azurerm_subnet.aks.id
}

resource "azurerm_kubernetes_cluster_node_pool" "tenant1" {
  name                  = "tenant1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  enable_auto_scaling   = true
  vm_size               = "Standard_F16s_v2"
  node_count            = 1
  max_count             = 2
  min_count             = 2
  max_pods              = 250
  orchestrator_version  = var.kubernetes_version
  zones                 = [1, 2, 3]
  mode                  = "User"
  node_labels           = { workloads = "tenant1" }
  node_taints           = ["workloads=tenant1:NoSchedule"]
  vnet_subnet_id        = data.azurerm_subnet.aks.id
}

resource "azurerm_kubernetes_cluster_node_pool" "tenant2" {
  name                  = "tenant2"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  enable_auto_scaling   = true
  vm_size               = "Standard_F16s_v2"
  node_count            = 1
  max_count             = 2
  min_count             = 2
  max_pods              = 250
  orchestrator_version  = var.kubernetes_version
  zones                 = [1, 2, 3]
  mode                  = "User"
  node_labels           = { workloads = "tenant2" }
  node_taints           = ["workloads=tenant2:NoSchedule"]
  vnet_subnet_id        = data.azurerm_subnet.aks.id
}

