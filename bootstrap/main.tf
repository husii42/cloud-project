# ─────────────────────────────────────────────
# Bootstrap: Remote State Storage Account
# ─────────────────────────────────────────────
#
# This is a SEPARATE, minimal Terraform configuration with its OWN local
# state. It exists to solve a chicken-and-egg problem documented in the main
# project's README ("Local Terraform State" limitation):
#
#   The main project's Storage Account is created BY Terraform, but a remote
#   backend needs a Storage Account to already exist before Terraform can
#   even start. Something has to create that first Storage Account using
#   local state - this configuration is that "something".
#
# Usage (run once, before ever running the main project with a remote backend):
#
#   cd bootstrap
#   terraform init
#   terraform apply
#   terraform output backend_config_snippet
#
# The state of THIS bootstrap configuration is intentionally kept local
# (a few resources that essentially never change after creation), while the
# main project's state moves to the Storage Account created here.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "project_name" {
  description = "Same project name used in the main project, to keep resource names recognisable"
  type        = string
}

variable "location" {
  description = "Azure region for the state storage account"
  type        = string
  default     = "swedencentral"
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.project_name}-tfstate"
  location = var.location
}

resource "azurerm_storage_account" "state" {
  name                     = "sttfstate${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Versioning protects against accidental state corruption/overwrite -
  # worth the small extra cost for a resource that holds the entire
  # infrastructure's state.
  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

output "backend_config_snippet" {
  description = "Paste this into the main project's providers.tf inside a terraform { backend \"azurerm\" {} } block"
  value = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name        = "${azurerm_storage_container.tfstate.name}"
    key                   = "terraform.tfstate"
  EOT
}
