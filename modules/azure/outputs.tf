output "openai_account_id" {
  value = azurerm_cognitive_account.openai.id
}

output "openai_endpoint" {
  value = "https://${azurerm_cognitive_account.openai.custom_subdomain_name}.openai.azure.com/"
}

output "openai_deployment_name" {
  value = azurerm_cognitive_deployment.chat.name
}

output "pe_subnet_id" {
  value = azurerm_subnet.openai_pe.id
}

output "key_vault_secret_name_api_key" {
  value = azurerm_key_vault_secret.api_key.name
}

output "key_vault_secret_name_endpoint" {
  value = azurerm_key_vault_secret.endpoint.name
}