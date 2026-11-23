# ARO HCP agentic stack

OpenShift 5 **Lightspeed**, **Cluster Observability (Perses)**, and **Red Hat Connectivity Link 1.5 MCP gateway** on an existing cluster.

- **Azure path:** `modules/azure` — OpenAI over Private Endpoint on ARO HCP.
- **AWS path:** `modules/aws` placeholder (Bedrock / ROSA).

**Networking:** Default bootstrap exposes **no public MCP URL** — Lightspeed uses in-cluster `openshift-mcp-server` only. A production-grade external endpoint (Gateway API + OAuth) is **future work**; see **[MCP gateway networking](guides/mcp-gateway-networking.md)** (roadmap + opt-in `ENABLE_MCP_GATEWAY_PUBLIC`).

[Platform contract](guides/platform-contract.md) · Installer [agentic stack guide](https://github.com/rh-mobb/validated-pattern-aro-hcp/blob/main/docs/guides/agentic-stack.md)