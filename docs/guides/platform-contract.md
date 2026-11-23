# Platform contract

The cluster installer publishes `platform.json`. This repository reads it and publishes `agentic.json` for bootstrap.

Run the installer to completion first. This checkout does not create the cluster, the VNet or VPC, the Key Vault or the Secrets Manager IAM role, or External Secrets Operator.

| Installer | Repository | `installer.cloud` | `llm_backend` here |
|-----------|------------|-------------------|--------------------|
| ARO HCP | [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) | `azure` | `azure` |
| ROSA HCP | [validated-pattern-terraform-rosa](https://github.com/rh-mobb/validated-pattern-terraform-rosa) | `aws` | `aws` |

`terraform/platform_locals.tf` rejects the cross product. An ARO contract cannot drive `modules/aws`, and a ROSA contract cannot drive `modules/azure`.

## Produce `platform.json`

```bash
# ARO HCP
make -C "$ARO_HCP_ROOT" cluster.<profile>.platform

# ROSA HCP
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<profile>.platform
```

The file is gitignored at `clusters/<profile>/platform.json` inside the installer. Point this repo's `platform_json` at it. The path is relative to `terraform/`:

```hcl
# ARO — clusters/public/terraform.tfvars
platform_json = "../../validated-pattern-aro-hcp/clusters/public/platform.json"

# ROSA — clusters/rosa-public/terraform.tfvars
platform_json = "../../vp-terraform-rosa/clusters/public/platform.json"
llm_backend   = "aws"
```

Set `ARO_HCP_ROOT` or `VP_TERRAFORM_ROSA_ROOT` / `ROSA_ROOT` so `make cluster.<profile>.apply` refreshes that file before Terraform runs.

### Portable core (`contract_version: 1`)

Both installers publish at least:

| Field | Use |
|-------|-----|
| `contract_version` | `1` |
| `installer` | `{ repository, cloud }` |
| `cluster_name`, `cluster_id` | Names and the Bedrock secret prefix |
| Version pins | `cluster_version` / `openshift_version` and node pool pins |
| `api_url` | Reachability |
| `oidc_issuer_url` | Workload identity, where the installer uses it |
| `machine_pools` | Pool summary |

Operator install (Cluster Observability, Lightspeed, Connectivity Link) is the same on both clouds once the cluster is OpenShift 5, `oc` works, and External Secrets can read the cloud secret store.

### Azure extensions

Published only by [the ARO contract](https://github.com/rh-mobb/validated-pattern-aro-hcp/blob/main/docs/guides/platform-contract.md). `llm_backend=azure` requires:

| Field | Use |
|-------|-----|
| `subscription_id`, `tenant_id`, `location` | ARM scope |
| `resource_group_name` | Customer resource group |
| `network.vnet_name` and subnet fields | Private endpoint subnet |
| `network.reserved.agentic_pe_subnet_prefix` | CIDR for that subnet (default `10.0.5.0/28`) |
| `key_vault_id`, `key_vault_name`, `key_vault_uri` | API key and endpoint secrets |
| `eso_client_id` | External Secrets workload identity |

### AWS extensions

Published only by [the ROSA contract](https://github.com/rh-mobb/validated-pattern-terraform-rosa/blob/main/docs/guides/platform-contract.md). `llm_backend=aws` requires:

| Field | Use |
|-------|-----|
| `aws_account_id`, `region` | Account and default Bedrock region |
| `network.*` | VPC context |
| `secrets_manager_role_arn` | External Secrets IRSA role |

Turn on `enable_secrets_manager_iam` on the ROSA recipe (GitOps bootstrap enables it unless you set `enable_secrets_manager_iam = false`). Add `<cluster_name>-lightspeed-bedrock` to installer `additional_secrets` so that role can read the secret this module creates.

## `agentic.json` (this repo → bootstrap)

`make cluster.<profile>.apply` writes gitignored `clusters/<profile>/agentic.json` from `terraform output -json agentic`. `scripts/gitops-bootstrap.sh` templates `OLSConfig` and the ExternalSecret from it.

With `llm_backend = "none"`, Terraform does not write a usable LLM contract. Create `agentic.json` yourself before bootstrap.

### Azure (`llm_backend: azure`)

```json
{
  "contract_version": 1,
  "llm_backend": "azure",
  "openai_endpoint": "https://<account>.openai.azure.com/",
  "openai_deployment_name": "gpt-5-mini",
  "openai_model_version": "2025-08-07",
  "key_vault_secret_api_key": "azure-openai-api-key",
  "key_vault_secret_endpoint": "azure-openai-endpoint",
  "lightspeed_llm_provider_name": "azure_openai",
  "lightspeed_secret_name": "lightspeed-azure-openai"
}
```

### AWS Bedrock (`llm_backend: aws`)

```json
{
  "contract_version": 1,
  "llm_backend": "aws",
  "bedrock_region": "ap-southeast-2",
  "bedrock_model_id": "deepseek.v3.2",
  "secrets_manager_secret_name": "<cluster>-lightspeed-bedrock",
  "lightspeed_llm_provider_name": "bedrock",
  "lightspeed_secret_name": "lightspeed-bedrock",
  "gitops_overlay": "aws"
}
```

Secrets Manager payload synced into `openshift-lightspeed/<lightspeed_secret_name>`:

| Key | Lightspeed uses it for | Source |
|-----|------------------------|--------|
| `region`, `model_id` | Bedrock provider | `bedrock_region` and `bedrock_model_id`. Confirm the model with `scripts/bedrock-discover.sh` |
| `aws_access_key_id`, `aws_secret_access_key` | Credential check | IAM user when `provision_bedrock_iam_user` is true (the default), or `bedrock_credentials_extra` |
| `apitoken` | Alternative to IAM keys | Customer-managed. The module does not create this key |

`gitops_overlay: aws` selects `gitops/overlays/aws`, which installs the same operator subscriptions as `gitops/overlays/public`. Bootstrap still renders the Bedrock `OLSConfig` and ExternalSecret from `agentic.json`; those objects are not inside the kustomize overlay.

## Handoff

```text
Installer (ARO or ROSA)
  apply → bootstrap → platform.json
        │
        ▼
This repo
  llm_backend=azure → modules/azure → agentic.json
  llm_backend=aws   → modules/aws   → agentic.json
        │
        ▼
bootstrap → Cluster Observability + Lightspeed + Connectivity Link + OLSConfig
```
