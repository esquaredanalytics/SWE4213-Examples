###############################################################################
# outputs.tf — Values printed after terraform apply
###############################################################################

output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "ACR login server URL — use this as the image prefix when pushing."
  value       = azurerm_container_registry.acr.login_server
}

output "app_url" {
  description = "Public URL of the portfolio app."
  value       = "https://${azurerm_container_app.portfolio.ingress[0].fqdn}"
}

output "db_host" {
  description = "PostgreSQL server hostname."
  value       = azurerm_postgresql_flexible_server.db.fqdn
}