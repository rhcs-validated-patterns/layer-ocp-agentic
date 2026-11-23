output "bedrock_region" {
  description = "AWS region for Bedrock/Mantle API (Lightspeed secret region field)"
  value       = local.bedrock_api_region
}

output "bedrock_model_id" {
  description = "Bedrock model ID written to Secrets Manager"
  value       = var.bedrock_model_id
}

output "secrets_manager_secret_name" {
  description = "Secrets Manager secret holding Bedrock metadata for ESO"
  value       = aws_secretsmanager_secret.lightspeed_bedrock.name
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Bedrock config secret"
  value       = aws_secretsmanager_secret.lightspeed_bedrock.arn
}

output "lightspeed_secret_name" {
  description = "ExternalSecret / OLS credentials secret name in openshift-lightspeed"
  value       = var.lightspeed_secret_name
}