# ─────────────────────────────────────────────
# Checking the Azure account which is logged in
# ─────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────────
# Random suffix
# ─────────────────────────────────────────────
# Azure requires Storage Account and Key Vault names to be globally unique
# across ALL Azure customers, not just within this subscription. Relying on
# project_name alone risks a naming collision with someone else's resource.
# A short random suffix, generated once and kept stable in the state file,
# makes the names unique without the user having to pick one by hand.
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

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

  project_name          = var.project_name
  environment           = var.environment
  location              = var.location
  resource_group_name   = azurerm_resource_group.main.name
  tags                  = var.tags
  web_app_principal_id  = module.appservice.managed_identity_principal_id
  random_suffix         = random_string.suffix.result
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
  web_app_principal_id      = module.appservice.managed_identity_principal_id
  random_suffix              = random_string.suffix.result
}

# ─────────────────────────────────────────────
# Module: App Service (Part II application host)
# ─────────────────────────────────────────────
#
# NOTE on key_vault_uri / storage_account_name below:
# These are NOT read from module.keyvault / module.storage outputs here.
# Reason: module.storage and module.keyvault both need this module's
# managed_identity_principal_id (to grant access), while this module's
# app_settings need values FROM storage/keyvault. Referencing the outputs
# directly would create a cycle: appservice -> keyvault -> appservice.
#
# Both names are fully deterministic from project_name/environment/random_suffix
# (see the naming convention inside modules/storage/main.tf and
# modules/keyvault/main.tf), so they are computed here with the exact same
# expressions instead of being read back from the modules. This breaks the
# cycle while still avoiding any duplicated *literal* values – only the
# naming pattern and the shared random_string.suffix resource are shared,
# which is already the case between the two modules today.
module "appservice" {
  source = "./modules/appservice"

  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  resource_group_name  = azurerm_resource_group.main.name
  tags                 = var.tags
  key_vault_uri        = "https://kv-${var.project_name}-${var.environment}-${random_string.suffix.result}.vault.azure.net"
  storage_account_name = "st${var.project_name}${var.environment}${random_string.suffix.result}"
}
