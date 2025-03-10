resource "azurerm_resource_group" "this" {
  location = "swedencentral"
  name     = "rg-softawebit-ai-swce"
}

resource "azurerm_cognitive_account" "this" {
  custom_subdomain_name = "softawebit-openai-swce"
  kind                  = "OpenAI"
  location              = "swedencentral"
  name                  = "softawebit-openai-swce"
  resource_group_name   = azurerm_resource_group.this.name
  sku_name              = "S0"

  network_acls {
    default_action = "Allow"
  }
}

locals {
  cognitive_deployments = [
    {
      name            = "gpt-4o"
      version         = "2024-11-20"
      sku_capacity    = 100
      upgrade_option  = null
      rai_policy_name = "Microsoft.DefaultV2"
    },
    {
      name            = "gpt-4o-mini"
      version         = "2024-07-18"
      sku_capacity    = 1001
      upgrade_option  = "OnceCurrentVersionExpired"
      rai_policy_name = "Microsoft.DefaultV2"
    },
    {
      name            = "o1-mini"
      version         = "2024-09-12"
      sku_capacity    = 100
      upgrade_option  = "OnceCurrentVersionExpired"
      rai_policy_name = "Microsoft.DefaultV2"
    },
    {
      name                       = "text-embedding-ada-002"
      version                    = "2"
      sku_capacity               = 240
      upgrade_option             = "NoAutoUpgrade"
      rai_policy_name            = "Microsoft.DefaultV2"
      sku_name                   = "Standard"
      dynamic_throttling_enabled = true
    }
  ]
}

resource "azurerm_cognitive_deployment" "deployments" {
  for_each = { for idx, deployment in local.cognitive_deployments : deployment.name => deployment }

  cognitive_account_id = azurerm_cognitive_account.this.id
  name                 = each.value.name
  rai_policy_name      = each.value.rai_policy_name

  model {
    format  = "OpenAI"
    name    = each.value.name
    version = each.value.version
  }

  sku {
    capacity = each.value.sku_capacity
    name     = try(each.value.sku_name, "GlobalStandard")
  }

  version_upgrade_option = "OnceNewDefaultVersionAvailable"

  dynamic_throttling_enabled = false

  depends_on = [
    azurerm_cognitive_account.this,
  ]
}

output "cognitive_account_api_base" {
  value       = azurerm_cognitive_account.this.endpoint
  description = "The base URL for the Azure Cognitive Services API."
}

output "cognitive_account_api_key" {
  value       = azurerm_cognitive_account.this.primary_access_key
  sensitive   = true
  description = "The API key for the Azure Cognitive Services account."
}