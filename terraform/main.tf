module "azure" {
  count  = var.llm_backend == "azure" ? 1 : 0
  source = "../modules/azure"

  cluster_name        = local.platform.cluster_name
  resource_group_name = local.platform.resource_group_name
  location            = local.platform.location
  vnet_name           = local.platform.network.vnet_name
  pe_subnet_prefix    = local.pe_prefix
  key_vault_id        = local.platform.key_vault_id
  openai_account_name = local.openai_account_name

  openai_model_name    = var.openai_model_name
  openai_model_version = var.openai_model_version
  openai_capacity      = var.openai_capacity
  tags                 = var.tags
}

module "aws" {
  count  = var.llm_backend == "aws" ? 1 : 0
  source = "../modules/aws"

  cluster_name     = local.platform.cluster_name
  region           = local.platform.region
  bedrock_region   = var.bedrock_region
  aws_account_id   = local.platform.aws_account_id
  bedrock_model_id = var.bedrock_model_id
  tags             = var.tags
}