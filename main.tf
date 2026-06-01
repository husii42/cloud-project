# ─────────────────────────────────────────────
# Checking the Azure account which is logged in
# ─────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ─────────────────────────────────────────────
# Module: Storage Account
# ─────────────────────────────────────────────
module "storage" {
  source = "./modules/storage" # --> with source terraform knows where the code for storage account is located

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# ─────────────────────────────────────────────
# Module: Key Vault
# ─────────────────────────────────────────────
module "keyvault" {
  source = "./modules/keyvault"

  project_name              = var.project_name
  environment               = var.environment
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  object_id                 = data.azurerm_client_config.current.object_id
  storage_connection_string = module.storage.primary_access_key # --> we can use the output from the storage module as input for the keyvault module  
  tags                      = var.tags
}

# ─────────────────────────────────────────────
# Module: App Service (prepared for Part II)
# ─────────────────────────────────────────────
module "appservice" {
  source = "./modules/appservice"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}
