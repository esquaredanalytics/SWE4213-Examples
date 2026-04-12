###############################################################################
# main.tf — Azure infrastructure for the Portfolio App
#
# Provisions:
#   • Resource Group
#   • Azure Container Registry (ACR)      — stores the Docker image
#   • Azure Container Apps Environment    — managed serverless container runtime
#   • Azure Container App                 — runs the portfolio app
#   • Azure Database for PostgreSQL       — stores portfolio data
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

provider "azurerm" {
  features {}
}

###############################################################################
# Resource Group
###############################################################################

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

###############################################################################
# Azure Container Registry (ACR)
###############################################################################

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true   # Needed so Container Apps can pull using admin creds

  tags = var.tags
}

###############################################################################
# Azure Database for PostgreSQL Flexible Server
###############################################################################

resource "azurerm_postgresql_flexible_server" "db" {
  name                   = var.db_server_name
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  sku_name               = "B_Standard_B1ms"   # Cheapest tier — fine for dev/course
  storage_mb             = 32768
  zone                   = "1"

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "portfolio" {
  name      = "portfolio"
  server_id = azurerm_postgresql_flexible_server.db.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Allow all Azure services to reach the database
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name      = "AllowAzureServices"
  server_id = azurerm_postgresql_flexible_server.db.id

  # Azure's special range that means "allow connections from within Azure"
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

###############################################################################
# Azure Container Apps
###############################################################################

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.app_name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.app_name}-env"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}

resource "azurerm_container_app" "portfolio" {
  name                         = var.app_name
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  # Pull the image from ACR using admin credentials
  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  secret {
    name  = "db-password"
    value = var.db_admin_password
  }

  template {
    container {
      name   = var.app_name
      image  = "${azurerm_container_registry.acr.login_server}/${var.app_name}:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.db.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.portfolio.name
      }
      env {
        name  = "DB_USER"
        value = var.db_admin_user
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name  = "DB_SSL"
        value = "true"   # Azure PostgreSQL requires SSL
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  # Expose the app publicly on port 3000
  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags
}