variable "cluster_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "pe_subnet_prefix" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "openai_account_name" {
  type        = string
  description = "Azure Cognitive Services account name (globally unique, alphanumeric)."
}

variable "openai_model_name" {
  type    = string
  default = "gpt-4o"
}

variable "openai_model_version" {
  type    = string
  default = "2024-08-06"
}

variable "openai_deployment_sku" {
  type        = string
  default     = "GlobalStandard"
  description = "Azure OpenAI deployment SKU (e.g. GlobalStandard; region/model dependent)."
}

variable "openai_capacity" {
  type        = number
  default     = 10
  description = "Deployment capacity (TPM scale unit per Azure OpenAI quota)."
}

variable "key_vault_secret_name_api_key" {
  type    = string
  default = "azure-openai-api-key"
}

variable "key_vault_secret_name_endpoint" {
  type    = string
  default = "azure-openai-endpoint"
}

variable "tags" {
  type    = map(string)
  default = {}
}