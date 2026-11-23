# Documentation

Published site: [https://rhcs-validated-patterns.github.io/layer-ocp-agentic/](https://rhcs-validated-patterns.github.io/layer-ocp-agentic/) (MkDocs Material, deployed from `main` via GitHub Actions). Local preview: `make docs-preview`.

Site home: [index.md](index.md). Start with [Choose an installer](prerequisites/index.md), then [Quick start](getting-started/quick-start.md).

| Document | Purpose |
|----------|---------|
| [Choose an installer](prerequisites/index.md) | ARO HCP or ROSA HCP must exist before this repo runs |
| [Account prerequisites](prerequisites/account.md) | Tools, Azure OpenAI quota, Bedrock and Secrets Manager |
| [Quick start](getting-started/quick-start.md) | Copy an example profile and apply, bootstrap, verify |
| [Agentic stack](guides/agentic-stack.md) | What bootstrap installs, kubeconfig, destroy order |
| [Platform contract](guides/platform-contract.md) | `platform.json` from the installer and `agentic.json` from this repo |
| [MCP gateway networking](guides/mcp-gateway-networking.md) | Public MCP stays off unless you opt in |
| [LLM modules](reference/modules.md) | `modules/azure` and `modules/aws` |
