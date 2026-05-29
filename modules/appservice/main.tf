# App Service Plan (the underlying compute)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1" # Basic tier – cheapest billable plan; free tier (F1) has no always-on

  tags = var.tags
}

# Web App – placeholder for Part II application code
resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  # System-assigned Managed Identity so the app can access Key Vault without secrets
  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    application_stack {
      python_version = "3.11" # Part II web app will use Python (Flask / FastAPI)
    }
  }

  # App Settings – Part II will add AZURE_STORAGE_* and KEY_VAULT_URI here
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"      = "true"
  }

  tags = var.tags
}
