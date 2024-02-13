module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
  suffix  = [var.spec.project, var.spec.location]
}

resource "azuread_group" "main" {
  display_name               = "${var.spec.project}-cluster-admins"
  assignable_to_role         = false
  auto_subscribe_new_members = false
  external_senders_allowed   = false
  mail_enabled               = false
  prevent_duplicate_names    = true
  security_enabled           = true
  owners                     = var.spec.cluster.admins
  members                    = var.spec.cluster.admins

  lifecycle {
    ignore_changes = [owners]
  }
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = var.spec.location
}

resource "azurerm_virtual_network" "main" {
  name                = module.naming.virtual_network.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = var.spec.virtual_network.address_space
}

resource "azurerm_subnet" "default" {
  name                 = module.naming.subnet.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [
    cidrsubnet(var.spec.virtual_network.address_space.0, 2, 0),
    cidrsubnet(var.spec.virtual_network.address_space.1, local.ipv6_mask_bits, 0)
  ]
}

resource "azurerm_subnet" "main" {
  for_each             = var.spec.zones
  name                 = "${module.naming.subnet.name}-zone-${each.value}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [
    cidrsubnet(var.spec.virtual_network.address_space.0, 2, tonumber(each.value)),
    cidrsubnet(var.spec.virtual_network.address_space.1, local.ipv6_mask_bits, tonumber(each.value))
  ]
}

resource "azurerm_public_ip_prefix" "ipv4" {
  name                = "${module.naming.public_ip_prefix.name}-ipv4"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  ip_version          = "IPv4"
  sku                 = "Standard"
  prefix_length       = 28
  zones               = var.spec.zones
}

resource "azurerm_public_ip_prefix" "ipv6" {
  name                = "${module.naming.public_ip_prefix.name}-ipv6"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  ip_version          = "IPv6"
  sku                 = "Standard"
  prefix_length       = 124
  zones               = var.spec.zones
}

resource "azurerm_user_assigned_identity" "cluster" {
  name                = "${module.naming.user_assigned_identity.name}-cluster"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${module.naming.user_assigned_identity.name}-kubelet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "cluster_managed_identity_operator_kubelet" {
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  role_definition_name = "Managed Identity Operator"
  scope                = azurerm_user_assigned_identity.kubelet.id
}

resource "azurerm_role_assignment" "cluster_network_contributor_network" {
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  role_definition_name = "Network Contributor"
  scope                = azurerm_virtual_network.main.id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                      = module.naming.kubernetes_cluster.name
  resource_group_name       = azurerm_resource_group.main.name
  node_resource_group       = "${azurerm_resource_group.main.name}-aks"
  location                  = azurerm_resource_group.main.location
  automatic_channel_upgrade = "node-image"
  node_os_channel_upgrade   = "NodeImage"
  dns_prefix                = var.spec.project
  kubernetes_version        = var.spec.cluster.version

  local_account_disabled            = true
  oidc_issuer_enabled               = true
  role_based_access_control_enabled = true
  workload_identity_enabled         = true

  image_cleaner_enabled               = false
  http_application_routing_enabled    = false
  run_command_enabled                 = false
  azure_policy_enabled                = false
  private_cluster_enabled             = false
  open_service_mesh_enabled           = false
  private_cluster_public_fqdn_enabled = false

  network_profile {
    network_plugin    = "none"
    pod_cidrs         = var.spec.cluster.pod_cidrs
    service_cidrs     = var.spec.cluster.service_cidrs
    dns_service_ip    = cidrhost(var.spec.cluster.service_cidrs.0, 10)
    ip_versions       = ["IPv4", "IPv6"]
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"

    load_balancer_profile {
      idle_timeout_in_minutes  = 4
      outbound_ports_allocated = min(16 * 64000 / local.max_node_count, 64000)
      outbound_ip_prefix_ids = [
        azurerm_public_ip_prefix.ipv4.id,
        azurerm_public_ip_prefix.ipv6.id
      ]
    }
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.cluster.id
    ]
  }

  default_node_pool {
    name                         = "default"
    temporary_name_for_rotation  = "temp"
    only_critical_addons_enabled = true
    enable_auto_scaling          = true
    min_count                    = var.spec.cluster.default_node_pool.min_count
    max_count                    = var.spec.cluster.default_node_pool.max_count
    max_pods                     = var.spec.cluster.default_node_pool.max_pods
    os_disk_size_gb              = var.spec.cluster.default_node_pool.os_disk_size_gb
    os_disk_type                 = var.spec.cluster.default_node_pool.os_disk_type
    os_sku                       = var.spec.cluster.default_node_pool.os_sku
    vm_size                      = var.spec.cluster.default_node_pool.vm_size
    vnet_subnet_id               = azurerm_subnet.default.id
    zones                        = var.spec.zones

    upgrade_settings {
      max_surge = var.spec.cluster.default_node_pool.max_surge
    }
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [azuread_group.main.id]
    managed                = true
    azure_rbac_enabled     = false
  }

  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  lifecycle {
    ignore_changes = [
      network_profile.0.pod_cidrs,
      network_profile.0.service_cidrs
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "main" {
  for_each              = local.node_pools
  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  enable_auto_scaling   = true
  mode                  = each.value.mode
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  max_pods              = each.value.max_pods
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  os_sku                = each.value.os_sku
  vm_size               = each.value.vm_size
  vnet_subnet_id        = each.value.subnet_id
  zones                 = [each.value.zone]

  upgrade_settings {
    max_surge = each.value.max_surge
  }
}

resource "azurerm_role_assignment" "cluster_admin_user_role" {
  scope                = azurerm_kubernetes_cluster.main.id
  principal_id         = azuread_group.main.object_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
}

resource "azapi_update_resource" "kube_proxy" {
  type        = "Microsoft.ContainerService/managedClusters@2023-08-02-preview"
  resource_id = azurerm_kubernetes_cluster.main.id

  body = jsonencode({
    properties = {
      networkProfile = {
        kubeProxyConfig = {
          enabled = false
        }
      }
    }
  })

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_kubernetes_cluster_node_pool.main
  ]
}
