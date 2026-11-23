# Azure OpenAI LLM module

Creates:

- PE subnet on the installer VNet (`agentic_pe_subnet_prefix` from `platform.json`)
- **Azure OpenAI** account (private network only) + model deployment
- Private Endpoint + `privatelink.openai.azure.com` zone
- Key Vault secrets for API key and endpoint (consumed by ESO → `lightspeed-azure-openai`)

**Requires** `platform.json` from [`validated-pattern-aro-hcp`](https://github.com/rh-mobb/validated-pattern-aro-hcp) with Azure extensions (`key_vault_id`, `network.vnet_name`, etc.).

Wired when root `llm_backend = "azure"` (default).