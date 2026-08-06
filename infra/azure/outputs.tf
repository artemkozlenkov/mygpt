output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "ai_foundry_hub_id" {
  value = azurerm_ai_foundry.main.id
}

output "ai_foundry_project_id" {
  value = azurerm_ai_foundry_project.main.id
}

output "openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "model_deployments" {
  value = keys(azurerm_cognitive_deployment.models)
}
