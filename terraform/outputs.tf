output "subscription_id" {
  value = try(local.platform.subscription_id, null)
}

output "tenant_id" {
  value = try(local.platform.tenant_id, null)
}

output "location" {
  value = try(local.platform.location, null)
}

output "resource_group_name" {
  value = try(local.platform.resource_group_name, null)
}

output "key_vault_name" {
  value = try(local.platform.key_vault_name, null)
}

output "platform_installer_cloud" {
  description = "installer.cloud from platform.json"
  value       = local.platform_installer_cloud
}

output "llm_backend" {
  value = var.llm_backend
}

output "openai_endpoint" {
  value = var.llm_backend == "azure" ? module.azure[0].openai_endpoint : null
}

output "openai_deployment_name" {
  value = var.llm_backend == "azure" ? module.azure[0].openai_deployment_name : null
}

output "agentic" {
  description = "Gitignored agentic.json contract for bootstrap."
  value = var.llm_backend == "azure" ? merge({
    contract_version                                             = 1
    llm_backend                                                  = "azure"
    openai_endpoint                                              = module.azure[0].openai_endpoint
    openai_deployment_name                                       = module.azure[0].openai_deployment_name
    openai_model_version                                         = var.openai_model_version
    key_vault_secret_api_key                                     = module.azure[0].key_vault_secret_name_api_key
    key_vault_secret_endpoint                                    = module.azure[0].key_vault_secret_name_endpoint
    lightspeed_llm_provider_name                                 = "azure_openai"
    lightspeed_secret_name                                       = "lightspeed-azure-openai"
    }, var.mcp_oauth_issuer_url != null ? { mcp_oauth_issuer_url = var.mcp_oauth_issuer_url } : {}, var.mcp_oauth_authorization_servers != null ? { mcp_oauth_authorization_servers = var.mcp_oauth_authorization_servers } : {}) : var.llm_backend == "aws" ? merge({
    contract_version                                             = 1
    llm_backend                                                  = "aws"
    bedrock_region                                               = module.aws[0].bedrock_region
    bedrock_model_id                                             = module.aws[0].bedrock_model_id
    secrets_manager_secret_name                                  = module.aws[0].secrets_manager_secret_name
    lightspeed_llm_provider_name                                 = "bedrock"
    lightspeed_secret_name                                       = module.aws[0].lightspeed_secret_name
    gitops_overlay                                               = "aws"
    }, var.mcp_oauth_issuer_url != null ? { mcp_oauth_issuer_url = var.mcp_oauth_issuer_url } : {}, var.mcp_oauth_authorization_servers != null ? { mcp_oauth_authorization_servers = var.mcp_oauth_authorization_servers } : {}) : {
    contract_version = 1
    llm_backend      = var.llm_backend
  }
}