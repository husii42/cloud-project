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

  # ───────────────────────────────────────────
  # Remote state backend (optional, see bootstrap/main.tf)
  # ───────────────────────────────────────────
  # Left commented out by default so the project keeps working with local
  # state out of the box. To migrate to remote state:
  #   1. cd bootstrap && terraform init && terraform apply
  #   2. Copy the values from `terraform output backend_config_snippet`
  #      into the block below and uncomment it
  #   3. Run `terraform init` again in the project root - Terraform will
  #      detect the new backend and offer to copy the existing local state
  #      into it automatically.
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-<project_name>-tfstate"
  #   storage_account_name = "sttfstate<project_name><suffix>"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true # to delete the key valut immediately when we run terraform destroy, instead of having to wait for 90 days until it is permanently deleted. This is useful for testing and development purposes, but should be used with caution in production environments.
      recover_soft_deleted_key_vaults = true # to recover the key vault if it is accidentally deleted. This is useful for testing and development purposes, but should be used with caution in production environments.
    }
  }
}
