###############################################################################
# outputs.tf — Values printed after terraform apply
###############################################################################

output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "ACR login server URL (used as the image prefix when pushing)."
  value       = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl to point at your new AKS cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
