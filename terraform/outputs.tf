output "ca_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate
  sensitive = true
}

output "host" {
  value     = azurerm_kubernetes_cluster.main.kube_config.0.host
  sensitive = true
}

output "cluster_admin_identity" {
  value = {
    id           = azurerm_user_assigned_identity.cluster_admin.id
    client_id    = azurerm_user_assigned_identity.cluster_admin.client_id
    principal_id = azurerm_user_assigned_identity.cluster_admin.principal_id
  }
}
