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

resource "azurerm_role_assignment" "cluster_admin_user_role" {
  scope                = azurerm_kubernetes_cluster.main.id
  principal_id         = azuread_group.main.object_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
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

resource "azuread_group" "main" {
  display_name               = "${var.spec.project}-cluster-admins"
  assignable_to_role         = false
  auto_subscribe_new_members = false
  external_senders_allowed   = false
  mail_enabled               = false
  prevent_duplicate_names    = true
  security_enabled           = true
  owners                     = [data.azuread_client_config.main.object_id]
}

resource "azuread_group_member" "main" {
  for_each         = var.spec.cluster.admins
  group_object_id  = azuread_group.main.object_id
  member_object_id = each.value
}

resource "azuread_group_member" "cluster_admin_identity" {
  group_object_id  = azuread_group.main.object_id
  member_object_id = data.azurerm_user_assigned_identity.meta.principal_id
}
