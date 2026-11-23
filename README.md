# layer-ocp-agentic

Day-2 OpenShift 5 agentic stack for a cluster that already exists.

| Layer | Repository |
|-------|------------|
| ARO HCP cluster, GitOps, External Secrets | [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) |
| ROSA HCP cluster, GitOps, External Secrets | [validated-pattern-terraform-rosa](https://github.com/rh-mobb/validated-pattern-terraform-rosa) |
| Cloud LLM and the agentic operators | **this repo** |

Create the cluster with one installer and publish its `platform.json`. This repo then installs Cluster Observability, OpenShift Lightspeed, and Red Hat Connectivity Link, plus either Azure OpenAI (`modules/azure`) or Amazon Bedrock (`modules/aws`).

Contracts: [Platform contract](docs/guides/platform-contract.md). Docs: [MkDocs site](https://rhcs-validated-patterns.github.io/layer-ocp-agentic/) (`make docs-preview` locally).

**MCP:** Default bootstrap does not expose a public MCP URL. See [MCP gateway networking](docs/guides/mcp-gateway-networking.md).

## Quick start

The installer cluster must already be applied, bootstrapped, and have `platform.json`. Full steps: [Choose an installer](docs/prerequisites/index.md) and [Quick start](docs/getting-started/quick-start.md).

### ARO HCP

```bash
export ARO_HCP_ROOT=/path/to/validated-pattern-aro-hcp
make -C "$ARO_HCP_ROOT" cluster.<name>.apply
make -C "$ARO_HCP_ROOT" cluster.<name>.kubeconfig
make -C "$ARO_HCP_ROOT" cluster.<name>.external-auth
make -C "$ARO_HCP_ROOT" cluster.<name>.bootstrap
make -C "$ARO_HCP_ROOT" cluster.<name>.platform

cp -r clusters/public clusters/my-agentic   # point platform_json at the installer file
make cluster.my-agentic.apply
make cluster.my-agentic.bootstrap
make cluster.my-agentic.verify
```

### ROSA HCP

```bash
export VP_TERRAFORM_ROSA_ROOT=/path/to/validated-pattern-terraform-rosa
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.apply
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.bootstrap
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.login
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.platform

cp -r clusters/rosa-public clusters/my-agentic   # llm_backend=aws; point platform_json at the installer file
make cluster.my-agentic.apply
make cluster.my-agentic.bootstrap
make cluster.my-agentic.verify
```

Do not set `ARO_HCP_ROOT` on the ROSA path. Bootstrap then uses `~/.kube/config` from the installer login.

**Destroy:** `make cluster.<name>.destroy` here **before** `make cluster.<name>.destroy` in the installer.

Cluster state, apply logs, and `agentic.json` stay on the machine (see `.gitignore`). Those files can contain cloud credentials. Do not force-add them.

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
