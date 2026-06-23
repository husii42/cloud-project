# App Service Plan (the underlying compute)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux" # Cheaper thgan Windows plans, and better for Python apps
  sku_name            = "B1" # Basic tier – cheapest billable plan; free tier (F1) has no always-on. Always-on is required for the app to stay responsive, so B1 is the cheapest viable option.

  tags = var.tags
}

# Web App – placeholder for Part II application code
resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  # System-assigned Managed Identity so the app can access Key Vault and
  # Storage without secrets
  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    # Azure's default Python startup uses Flask's dev server, which is not
    # suitable beyond local development. Gunicorn is the production WSGI
    # server; "app:app" means "in app.py, use the object named app" (the
    # Flask instance created in app.py).
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 app:app"

    application_stack {
      python_version = "3.11" # Part II web app will use Python (Flask / FastAPI), as Python is the only language I know
    }
  }

  # App Settings – the app reads these at runtime to find its resources.
  # No secrets are stored here: the app authenticates via its Managed Identity,
  # so only non-sensitive configuration values (names, URIs) are needed.
  #
  # NOTE on dependency direction: these values are passed in as plain
  # variables (var.key_vault_uri, var.storage_account_name) rather than
  # module outputs referenced directly here. This module's own output
  # (managed_identity_principal_id) is what the storage/keyvault modules
  # need to grant access – if this resource instead depended on their
  # outputs for its own app_settings, Terraform would see a cycle between
  # modules (appservice -> keyvault -> appservice). Computing the Key Vault
  # URI and Storage Account name from the same naming convention used in
  # those modules (in the root module, see main.tf) avoids that cycle while
  # still avoiding any hardcoded/duplicated literal values.
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"      = "true" # to install Python packages automatically every time the code is updated 
    "KEY_VAULT_URI"                       = var.key_vault_uri
    "AZURE_STORAGE_ACCOUNT_NAME"          = var.storage_account_name
    "AZURE_STORAGE_CONTAINER_NAME"        = var.storage_container_name
  }

  tags = var.tags
}
