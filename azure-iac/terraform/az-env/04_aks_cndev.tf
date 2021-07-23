resource "azurerm_kubernetes_cluster" "aks_cndev" {
  name                = "cndev"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_tier            = "Free"
  kubernetes_version  = var.kubernetes_version

  dns_prefix = "${var.aks_cluster_name}-aks"
  # private_cluster_enabled = true
  # node_resource_group = "aks-mc-${azurerm_resource_group.rg.name}"

  default_node_pool {
    name                 = "default"
    type                 = "VirtualMachineScaleSets"
    vm_size              = "Standard_D2as_v4"
    availability_zones   = ["1", "2", "3"]
    enable_auto_scaling  = true
    node_count           = 2
    max_count            = 3
    min_count            = 2
    orchestrator_version = var.kubernetes_version
    vnet_subnet_id       = data.azurerm_subnet.aks2.id
  }

  linux_profile {
    admin_username = "suren"
    ssh_key {
      key_data = file("../files/id_rsa.pub")
    }
  }

  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.2.0.0/24"
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed = true
    }
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
    }
    azure_policy {
      enabled = true
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-control-plane-mi
  identity {
    type = "SystemAssigned"
    # user_assigned_identity_id = data.azurerm_user_assigned_identity.aks_controlplane_ua_mi.id
  }

  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster (see identity)
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity
  # kubelet_identity {
  #   user_assigned_identity_id = data.azurerm_user_assigned_identity.aks_kubelet_ua_mi.id
  #   client_id                 = data.azurerm_user_assigned_identity.aks_kubelet_ua_mi.client_id
  #   object_id                 = data.azurerm_user_assigned_identity.aks_kubelet_ua_mi.principal_id
  # }

}

resource "azurerm_kubernetes_cluster_node_pool" "aks_cndev_common" {
  name                  = "common"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cndev.id
  enable_auto_scaling   = true
  vm_size               = "Standard_D2as_v4"
  node_count            = 2
  max_count             = 3
  min_count             = 2
  max_pods              = 30
  orchestrator_version  = var.kubernetes_version
  availability_zones    = [1, 2, 3]
  mode                  = "User"
  node_labels           = { workloads = "general" }
  vnet_subnet_id        = data.azurerm_subnet.aks2.id
}

# If using System-Assigned MI, ensure it has access to subnet
# az aks show -n <clustername> -g <rgname> --query=identity (or identityProfile for kubeletIdentity)
# az role assignment list --assignee <Id> --all -o table
# az role assignment create --assignee $ASSIGNEE --role 'Network Contributor' --scope $VNETID

# Make sure the SP executing this template has access for role assignment (owner on that RG)
resource "azurerm_role_assignment" "assignment" {
  principal_id         = azurerm_kubernetes_cluster.aks_cndev.identity[0].principal_id
  role_definition_name = "Network Contributor"

  # Increase the scope to VNET or RG level Only if subnet-level is insufficient (likewise for NSG)
  scope = data.azurerm_subnet.aks2.id
}


# Check with az and jq
# az aks show -n cndev -g azenv-uks --query=identity | jq '.principalId' | xargs az role assignment list --all -o table --assignee