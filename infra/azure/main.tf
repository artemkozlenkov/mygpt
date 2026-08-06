# ─── Resource group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ─── AI Foundry hub supporting resources ──────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  tags                       = var.tags
}

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = var.app_insights_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# ─── AI Foundry hub + project ─────────────────────────────────────────────────
resource "azurerm_ai_foundry" "main" {
  name                   = var.ai_foundry_name
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  storage_account_id     = azurerm_storage_account.main.id
  key_vault_id           = azurerm_key_vault.main.id
  application_insights_id = azurerm_application_insights.main.id
  friendly_name          = var.ai_foundry_name
  tags                   = var.tags

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_application_insights.main]
}

resource "azurerm_ai_foundry_project" "main" {
  name               = var.ai_foundry_project_name
  location           = azurerm_resource_group.main.location
  ai_services_hub_id = azurerm_ai_foundry.main.id
  friendly_name      = var.ai_foundry_project_name
  tags               = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# ─── Azure OpenAI account + model deployments ─────────────────────────────────
resource "azurerm_cognitive_account" "openai" {
  name                  = var.openai_account_name
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = var.openai_account_name
  tags                  = var.tags
}

resource "azurerm_cognitive_deployment" "models" {
  for_each             = var.model_deployments
  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = each.value.format
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = each.value.sku
    capacity = each.value.capacity
  }
}
