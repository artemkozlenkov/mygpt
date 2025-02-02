data "azurerm_client_config" "current" {}

resource "azurerm_application_insights" "ml_app_insights" {
  name                = var.application_insights_name
  location            = azurerm_resource_group.new_rg.location
  resource_group_name = azurerm_resource_group.new_rg.name
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_resource_group" "new_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "ml_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.new_rg.name
  location                 = azurerm_resource_group.new_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "terraform-state"
  storage_account_id    = azurerm_storage_account.ml_storage.id
  container_access_type = "private"
}

resource "azurerm_key_vault" "ml_key_vault" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.new_rg.location
  resource_group_name = azurerm_resource_group.new_rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # access_policy {
  #   tenant_id = data.azurerm_client_config.current.tenant_id
  #   object_id = azurerm_machine_learning_workspace.artem_ml_workspace.identity[0].principal_id
  #   key_permissions = ["get", "list"]
  #   secret_permissions = ["get", "list"]
  # }

  tags = var.tags
}

resource "azurerm_machine_learning_workspace" "artem_ml_workspace" {
  friendly_name           = var.hub_name
  key_vault_id            = azurerm_key_vault.ml_key_vault.id
  location                = var.location
  name                    = var.hub_name
  resource_group_name     = azurerm_resource_group.new_rg.name
  storage_account_id      = azurerm_storage_account.ml_storage.id
  application_insights_id = azurerm_application_insights.ml_app_insights.id

  tags = merge(
    var.tags
  )

  identity {
    type = "SystemAssigned"
  }
}