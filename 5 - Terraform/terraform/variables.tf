###############################################################################
# variables.tf — Input variables for the Portfolio App deployment
###############################################################################

variable "resource_group_name" {
  description = "Name of the Azure Resource Group."
  type        = string
  default     = "portfolio-rg"
}

variable "location" {
  description = "Azure region to deploy into."
  type        = string
  default     = "canadacentral"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry. Must be globally unique, alphanumeric only."
  type        = string
  # No default — must be set in terraform.tfvars
}

variable "app_name" {
  description = "Name used for the Container App and related resources."
  type        = string
  default     = "portfolio"
}

variable "db_server_name" {
  description = "Name of the PostgreSQL Flexible Server. Must be globally unique."
  type        = string
  # No default — must be set in terraform.tfvars
}

variable "db_admin_user" {
  description = "Administrator username for PostgreSQL."
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL."
  type        = string
  sensitive   = true
  # No default — must be set in terraform.tfvars (never commit this)
}

variable "tags" {
  description = "Tags applied to all Azure resources."
  type        = map(string)
  default = {
    project     = "portfolio"
    environment = "dev"
    course      = "SWE4213"
  }
}