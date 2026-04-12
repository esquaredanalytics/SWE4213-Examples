###############################################################################
# variables.tf — Input variables for the Video Streaming Azure deployment
###############################################################################

variable "resource_group_name" {
  description = "Name of the Azure Resource Group that contains all resources."
  type        = string
  default     = "video-streaming-rg"
}

variable "location" {
  description = "Azure region to deploy into (e.g. eastus, canadacentral)."
  type        = string
  default     = "canadacentral"
}

variable "acr_name" {
  description = <<-EOT
    Name of the Azure Container Registry.
    Must be globally unique, 5–50 alphanumeric characters (no hyphens or underscores).
  EOT
  type        = string
  default     = "videostreamingacr"   # ← Change this to something unique to you
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "video-streaming-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Leave blank for latest stable."
  type        = string
  default     = null
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes. Standard_B2s is cheap for development."
  type        = string
  default     = "Standard_B2s"
}

variable "tags" {
  description = "Tags applied to all Azure resources."
  type        = map(string)
  default = {
    project     = "video-streaming"
    environment = "dev"
    course      = "SWE4213"
  }
}
