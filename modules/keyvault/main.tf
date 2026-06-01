resource "azurerm_key_vault" "main" {
  # Key Vault names: 3-24 chars, alphanumeric + hyphens
  name                        = "kv-${var.project_name}-${var.environment}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard" # Cheapest SKU, sufficient for this demo
  soft_delete_retention_days  = 7 # Minimum retention period for soft-deleted vaults, required by Azure (cannot be set to 0 or disabled).
  purge_protection_enabled    = false # For university exercises, we disable purge protection to allow quick cleanup. In production, you would likely want to enable it for better security.

  tags = var.tags
}

# Grant the current CLI user full access to the Key Vault 
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover"
  ]

  key_permissions = [
    "Get", "List", "Create", "Delete"
  ]
}

# Store the Storage Account connection string as a secret (Part II will read this)
resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = var.storage_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}
