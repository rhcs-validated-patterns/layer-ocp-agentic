# ROSA HCP + Bedrock path (sibling checkout: vp-terraform-rosa)
# 1. make -C ../vp-terraform-rosa cluster.<profile>.apply
# 2. VP_TERRAFORM_ROSA_ROOT=../vp-terraform-rosa make cluster.rosa-public.plan
platform_json = "../../vp-terraform-rosa/clusters/public/platform.json"

llm_backend = "aws"

# Mantle in same region as ROSA. DeepSeek v3.2 — Red Hat-tested on Bedrock; better tool_calls vs Qwen text leaks.
bedrock_region   = "ap-southeast-2"
bedrock_model_id = "deepseek.v3.2"

# Public MCP edge is OFF by default — see docs/guides/mcp-gateway-networking.md (roadmap).
# When ready: ENABLE_MCP_GATEWAY_PUBLIC=true on bootstrap + set OIDC (merged into agentic.json on apply):
# mcp_oauth_issuer_url = "https://keycloak.example.com/realms/mcp"
# mcp_oauth_authorization_servers = ["https://keycloak.example.com/realms/mcp"]