variable "cluster_name" {
  description = "ROSA cluster name from platform.json"
  type        = string
  nullable    = false
}

variable "region" {
  description = "AWS region from platform.json (cluster home region)"
  type        = string
  nullable    = false
}

variable "bedrock_region" {
  description = "Bedrock/Mantle API region in SM secret and OLSConfig. Defaults to region; override when APAC cluster uses US Mantle (Lightspeed ap. inference-prefix workaround)."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_account_id" {
  description = "AWS account ID from platform.json"
  type        = string
  nullable    = false
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock foundation model ID for Lightspeed (must be enabled in the account)"
  type        = string
  default     = "openai.gpt-oss-20b"
}

variable "lightspeed_secret_name" {
  description = "Kubernetes ExternalSecret name (also used as Secrets Manager secret name suffix)"
  type        = string
  default     = "lightspeed-bedrock"
}

variable "tags" {
  description = "Tags applied to AWS resources"
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "provision_bedrock_iam_user" {
  description = "Create a scoped IAM user + access key in Secrets Manager for Lightspeed Bedrock (dev/test). Set false when supplying keys via bedrock_credentials_extra."
  type        = bool
  default     = true
  nullable    = false
}

variable "bedrock_credentials_extra" {
  description = "Extra keys merged into the Lightspeed Bedrock SM secret (e.g. static credentials from an external vault)."
  type        = map(string)
  default     = {}
  nullable    = false
  sensitive   = true
}