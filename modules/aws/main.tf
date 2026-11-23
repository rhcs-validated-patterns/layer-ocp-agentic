# Day-2 LLM IaC for ROSA: store Bedrock routing metadata in Secrets Manager for ESO → Lightspeed.
# Invocation uses IAM from the cluster (IRSA); no static Bedrock API key is required.

resource "aws_secretsmanager_secret" "lightspeed_bedrock" {
  name = "${var.cluster_name}-${var.lightspeed_secret_name}"
  tags = merge(var.tags, {
    component  = "agentic"
    managed_by = "validated-pattern-aro-agentic"
  })
}

resource "aws_secretsmanager_secret_version" "lightspeed_bedrock" {
  secret_id     = aws_secretsmanager_secret.lightspeed_bedrock.id
  secret_string = jsonencode(local.bedrock_secret_payload)
}