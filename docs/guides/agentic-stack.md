# Deploy the agentic stack

1. Complete the [installer agentic guide](https://github.com/rh-mobb/validated-pattern-aro-hcp/blob/main/docs/guides/agentic-stack.md) through `platform`.
2. Set `ARO_HCP_ROOT` to the installer checkout.
3. Set `llm_backend` in `clusters/<profile>/terraform.tfvars` (`azure` default, `none` to skip LLM IaC). See [Platform contract](platform-contract.md).
4. `make cluster.<profile>.apply` → writes `agentic.json` (when `llm_backend=azure`).
5. `make cluster.<profile>.bootstrap` → operators + `OLSConfig`.
6. `make cluster.<profile>.verify`.

Public MCP on **`https://mcp.<ingress-domain>/…`** is **off by default**. Read **[MCP gateway networking](mcp-gateway-networking.md)** for the roadmap (IdP + MCP OAuth 2.1) and lab opt-in (`ENABLE_MCP_GATEWAY_PUBLIC=true`). Lightspeed’s in-cluster `openshift-mcp-server` does not require the public gateway.

Destroy this repo **before** destroying the ARO HCP cluster.