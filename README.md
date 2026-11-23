# validated-pattern-aro-agentic

Second IaC run for **OpenShift 5 agentic** features on an existing OpenShift cluster (today: [ARO HCP](https://github.com/rh-mobb/validated-pattern-aro-hcp); future: ROSA + Bedrock).

| Layer | Repo |
|-------|------|
| Cluster + baseline GitOps | Installer (e.g. `validated-pattern-aro-hcp`, future `vp-terraform-rosa`) |
| Cloud LLM IaC + operators | **this repo** (`modules/azure`; `modules/aws` placeholder) |

Contracts: [Platform contract](docs/guides/platform-contract.md).

**MCP:** Default bootstrap does **not** expose a public MCP URL; see [MCP gateway networking](docs/guides/mcp-gateway-networking.md) for roadmap and lab opt-in.

## Quick start

```bash
# Installer checkout
export ARO_HCP_ROOT=/path/to/validated-pattern-aro-hcp
make -C "$ARO_HCP_ROOT" cluster.aro-agentic.apply
make -C "$ARO_HCP_ROOT" cluster.aro-agentic.kubeconfig
make -C "$ARO_HCP_ROOT" cluster.aro-agentic.external-auth
make -C "$ARO_HCP_ROOT" cluster.aro-agentic.bootstrap
make -C "$ARO_HCP_ROOT" cluster.aro-agentic.platform

# This checkout
cp -r clusters/public clusters/my-agentic   # edit platform_json path
make cluster.my-agentic.apply
make cluster.my-agentic.bootstrap
make cluster.my-agentic.verify
```

**Destroy:** `make cluster.<name>.destroy` here **before** `make cluster.<name>.destroy` in the installer.

Cluster state, apply logs, and `agentic.json` stay on the machine (see `.gitignore`). Those files can contain cloud credentials. Do not force-add them.

Docs: [Agentic stack guide](docs/guides/agentic-stack.md) (installer) · [MkDocs](docs/index.md)

## License

Copyright 2026 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.