# Agentic stack

Two checkouts, one cluster. The installer creates OpenShift 5 and baseline GitOps. This checkout creates the LLM resources and installs:

| Component | Namespace | Role |
|-----------|-----------|------|
| Cluster Observability Operator | `openshift-cluster-observability-operator` | Perses UI plugin |
| OpenShift Lightspeed | `openshift-lightspeed` | Console assistant, `OLSConfig` |
| Red Hat Connectivity Link | `kuadrant-system` | MCP gateway operator (public URL is off by default) |

Lightspeed talks to in-cluster `openshift-mcp-server`. A public `https://mcp.<ingress-domain>/` listener is not created unless you set `ENABLE_MCP_GATEWAY_PUBLIC=true`. Read [MCP gateway networking](mcp-gateway-networking.md) before turning that on.

## Before apply

1. Installer cluster is Ready and bootstrapped. [Choose an installer](../prerequisites/index.md).
2. `platform.json` matches the cloud you intend to use. [Platform contract](platform-contract.md).
3. Quota and IAM from [Account prerequisites](../prerequisites/account.md) are in place.
4. Unset stray `TF_VAR_*` in the shell. This Makefile passes the profile `terraform.tfvars` explicitly.

## Apply

```bash
make cluster.<profile>.apply
```

That refreshes `platform.json` when `ARO_HCP_ROOT` or `VP_TERRAFORM_ROSA_ROOT` is set, applies Terraform, and writes `clusters/<profile>/agentic.json`.

| `llm_backend` | Terraform creates |
|---------------|-------------------|
| `azure` | OpenAI account, private endpoint, Key Vault secrets |
| `aws` | Secrets Manager secret `<cluster>-lightspeed-bedrock`, and by default an IAM user for Bedrock |
| `none` | Nothing in the cloud. You write `agentic.json` before bootstrap |

## Bootstrap and verify

```bash
make cluster.<profile>.bootstrap
make cluster.<profile>.verify
```

Kubeconfig:

| Installer | What to export | File bootstrap reads |
|-----------|----------------|----------------------|
| ARO HCP | `ARO_HCP_ROOT` | `$ARO_HCP_ROOT/.kube/config` |
| ROSA HCP | `VP_TERRAFORM_ROSA_ROOT` only | `~/.kube/config` after installer `make cluster.<name>.login` |

Override either path with `KUBECONFIG` / `KUBECONFIG_PATH`.

Bootstrap waits until the three ClusterServiceVersions succeed, waits for the Lightspeed ExternalSecret, and applies `OLSConfig`. It plants Argo CD `Application` **`agentic-stack`** from **`GITOPS_REPO`** (default `https://github.com/rhcs-validated-patterns/layer-ocp-agentic.git`, revision `main`, overlay from `llm_backend`). Override with `GITOPS_REPO` / `GITOPS_REVISION` on bootstrap.

Verify checks those CSVs, the ExternalSecret, and `OLSConfig`.

On ROSA, if the ExternalSecret never becomes Ready, confirm the installer role can read `<cluster>-lightspeed-bedrock` (`additional_secrets` on the ROSA recipe) and re-apply the installer if you added that name after the first cluster apply. Run installer **`make cluster.<name>.login`** before agentic bootstrap so `KUBECONFIG` reaches the API.

## Destroy

```bash
make cluster.<profile>.destroy
```

Then destroy the cluster in the installer. Removing the cluster first leaves the private endpoint, Key Vault secrets, or Secrets Manager secret behind, and it removes the API this bootstrap needs.

## Layout

```text
clusters/<profile>/terraform.tfvars   # platform_json + llm_backend
terraform/                             # root module, reads platform.json
modules/azure/                         # ARO path
modules/aws/                           # ROSA path
gitops/overlays/public/                # operator subscriptions
gitops/overlays/aws/                   # same subscriptions; Bedrock overlay marker
scripts/gitops-bootstrap.sh            # operators + OLSConfig
scripts/verify.sh
```
