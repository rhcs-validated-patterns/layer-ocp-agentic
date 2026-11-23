# Dev/test IAM user for Lightspeed Bedrock (OLS requires aws_access_key_id/aws_secret_access_key in the synced Secret).
# Production may use a pre-provisioned secret via var.bedrock_credentials_secret_version instead.

resource "aws_iam_user" "bedrock_lightspeed" {
  count = var.provision_bedrock_iam_user ? 1 : 0
  name  = "${var.cluster_name}-lightspeed-bedrock"
  path  = "/"
  tags  = merge(var.tags, { component = "agentic", purpose = "lightspeed-bedrock" })
}

resource "aws_iam_access_key" "bedrock_lightspeed" {
  count = var.provision_bedrock_iam_user ? 1 : 0
  user  = aws_iam_user.bedrock_lightspeed[0].name
}

resource "aws_iam_user_policy" "bedrock_invoke" {
  count = var.provision_bedrock_iam_user ? 1 : 0
  name  = "${var.cluster_name}-bedrock-invoke"
  user  = aws_iam_user.bedrock_lightspeed[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "BedrockInvoke"
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ListFoundationModels",
        "bedrock:ListInferenceProfiles",
        "bedrock:GetFoundationModel",
        "bedrock:GetInferenceProfile",
        "bedrock-mantle:CreateInference",
        "bedrock-mantle:ListModels",
      ]
      Resource = "*"
    }]
  })
}

locals {
  bedrock_api_region = coalesce(var.bedrock_region, var.region)

  bedrock_secret_payload = merge(
    {
      region   = local.bedrock_api_region
      model_id = var.bedrock_model_id
    },
    var.provision_bedrock_iam_user ? {
      aws_access_key_id     = aws_iam_access_key.bedrock_lightspeed[0].id
      aws_secret_access_key = aws_iam_access_key.bedrock_lightspeed[0].secret
    } : {},
    var.bedrock_credentials_extra
  )
}