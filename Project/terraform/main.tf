###############################################################################
# main.tf — Azure infrastructure for the Video Streaming App
#
# Provisions:
#   • Resource Group
#   • Azure Container Registry (ACR) — stores Docker images
#   • Azure Kubernetes Service (AKS) — runs the application
#   • Role assignment so AKS can pull images from ACR
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
  # Credentials are read from environment variables:
  #   ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
  # Or use: az login (Azure CLI)
}

###############################################################################
# Resource Group
###############################################################################

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

###############################################################################
# Azure Container Registry (ACR)
###############################################################################

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name   # Must be globally unique, alphanumeric only
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"        # Basic is fine for dev/course; use Standard/Premium in prod
  admin_enabled       = false          # We use the AKS managed identity instead of admin credentials

  tags = var.tags
}

###############################################################################
# Azure Kubernetes Service (AKS)
###############################################################################

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_cluster_name

  # Kubernetes version — leave blank to use the latest stable
  kubernetes_version = var.kubernetes_version

  # Default node pool (system pool — runs AKS infrastructure pods)
  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    os_disk_size_gb     = 50
    type                = "VirtualMachineScaleSets"

    # Enable auto-scaling (optional — remove min/max to use fixed node_count)
    # enable_auto_scaling = true
    # min_count           = 1
    # max_count           = 3
  }

  # Use a system-assigned managed identity so AKS can manage its own resources
  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled = true

  # Network profile — kubenet is simplest; use azure CNI for advanced networking
  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "standard"
  }

  tags = var.tags
}

###############################################################################
# Grant AKS permission to pull images from ACR
#
# AKS uses its kubelet identity (not the control-plane identity) to pull images.
# The AcrPull role on the ACR resource is the correct minimal permission.
###############################################################################

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
