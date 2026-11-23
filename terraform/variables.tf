variable "platform_json" {
  description = "Installer platform.json path (make cluster.<profile>.platform)."
  type        = string
}

variable "llm_backend" {
  description = "Cloud LLM IaC: azure (OpenAI PE + KV secrets), none (skip LLM Terraform; supply agentic.json for bootstrap). aws reserved for modules/aws."
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "none", "aws"], var.llm_backend)
    error_message = "llm_backend must be azure, aws, or none."
  }
}

variable "aws_region" {
  description = "Fallback AWS region when platform.json is not yet loaded (normally use platform.region)."
  type        = string
  default     = "us-east-1"
}

variable "bedrock_region" {
  description = "Bedrock/Mantle region for Lightspeed (optional; defaults to platform region). Use e.g. us-east-1 for Mantle when cluster is in APAC."
  type        = string
  default     = null
  nullable    = true
}

variable "bedrock_model_id" {
  description = "Bedrock foundation model ID when llm_backend=aws."
  type        = string
  default     = "openai.gpt-oss-20b"
}

variable "mcp_oauth_issuer_url" {
  description = "OIDC issuer URL for external MCP gateway AuthPolicy (Keycloak realm, Entra tenant, etc.). Written to agentic.json; not the OpenShift oauth.apps host."
  type        = string
  nullable    = true
  default     = null
}

variable "mcp_oauth_authorization_servers" {
  description = "OAuth authorization server URLs for MCP protected-resource metadata (defaults to mcp_oauth_issuer_url when unset)."
  type        = list(string)
  nullable    = true
  default     = null
}

variable "openai_account_name_suffix" {
  description = "Suffix for globally unique OpenAI account name (cluster_name + suffix)."
  type        = string
  default     = "oai"
}

variable "openai_model_name" {
  type    = string
  default = "gpt-5-mini"
}

variable "openai_model_version" {
  type    = string
  default = "2025-08-07"
}

variable "openai_capacity" {
  type    = number
  default = 10
}

variable "pe_subnet_prefix" {
  description = "Override reserved agentic PE CIDR from platform.json when set."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}