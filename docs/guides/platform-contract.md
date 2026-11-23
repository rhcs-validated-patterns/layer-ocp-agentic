# Platform and agentic contracts

This checkout is **cloud-agnostic at the GitOps layer** (COO, Lightspeed, RHCL). **LLM IaC** is selected by `llm_backend` in cluster `terraform.tfvars`.

| `llm_backend` | Terraform | GitOps bootstrap |
|---------------|-----------|------------------|
| `azure` (default) | `modules/azure` | Azure `OLSConfig` + `lightspeed-azure-openai` ExternalSecret |
| `aws` | `modules/aws` | Bedrock `OLSConfig` + SM-backed ExternalSecret (`gitops_overlay: aws`) |
| `none` | No LLM resources | Operator install only; **you** must write complete `agentic.json` before bootstrap |

## `platform.json` (cluster installer → this repo)

Published by the cluster installer:

```bash
# ARO HCP
make -C "$ARO_HCP_ROOT" cluster.<profile>.platform

# ROSA HCP
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<profile>.platform
```

Or set `VP_TERRAFORM_ROSA_ROOT` / `ROSA_ROOT` so `make cluster.<profile>.plan` runs `refresh-platform` automatically.

**Portable core** (`contract_version: 1`): `installer.{repository,cloud}`, `cluster_name`, `cluster_id`, `openshift_version` / version pins, `api_url`, `oidc_issuer_url`, `machine_pools`, …

**Azure extensions:** [ARO installer contract](https://github.com/rh-mobb/validated-pattern-aro-hcp/blob/main/docs/guides/platform-contract.md) — `subscription_id`, `key_vault_*`, `network.reserved.agentic_pe_subnet_prefix`, …

**AWS extensions (ROSA):** [vp-terraform-rosa contract](https://github.com/rh-mobb/validated-pattern-terraform-rosa/blob/main/docs/guides/platform-contract.md) — `aws_account_id`, `region`, `network.*`, `secrets_manager_role_arn`, …

Root Terraform reads `platform_json` and validates cloud prerequisites in `terraform/platform_locals.tf`.

## `agentic.json` (this repo → bootstrap)

Written by `make cluster.<profile>.apply` (or hand-edited when `llm_backend = "none"`).

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
  "bedrock_model_id": "openai.gpt-oss-20b",
  "secrets_manager_secret_name": "<cluster>-lightspeed-bedrock",
  "lightspeed_llm_provider_name": "bedrock",
  "lightspeed_secret_name": "lightspeed-bedrock",
  "gitops_overlay": "aws"
}
```

**Secrets Manager payload** (synced by ESO into `openshift-lightspeed/<lightspeed_secret_name>`):

| Key | Required by Lightspeed | Source |
|-----|------------------------|--------|
| `region`, `model_id` | Bedrock provider config | Use IDs from Mantle `GET /v1/models` for your `bedrock_region` (see `scripts/bedrock-discover.sh`); pick one that passes `POST /v1/chat/completions` |
| `aws_access_key_id`, `aws_secret_access_key` | Credential validation | `provision_bedrock_iam_user` (default `true`) or `bedrock_credentials_extra` |
| `apitoken` | Alternative to IAM keys | Customer-managed secret (not created by default module) |

On the **installer** cluster, add the SM secret name to `additional_secrets` so the ESO IRSA role can read it (after `make cluster.<name>.apply` in this repo knows the name, or use `{cluster}-lightspeed-bedrock`).

`scripts/gitops-bootstrap.sh` templates Bedrock `OLSConfig` (`url`, `defaultModel`) and the Secrets Manager `ExternalSecret` from `agentic.json`.

## Module layout

```text
modules/
  azure/     # OpenAI + PE + Key Vault (ARO)
  aws/       # Bedrock metadata in Secrets Manager (ROSA)
terraform/
  main.tf
  platform_locals.tf
gitops/overlays/
  public/    # operator subscriptions
  aws/       # Argo path for ROSA Bedrock stacks
```

## Workflow (ROSA)

```text
vp-terraform-rosa    platform.json (core + AWS)
        │
        ▼
This repo              llm_backend=aws → modules/aws → agentic.json
        │
        ▼
GitOps bootstrap       COO + Lightspeed + RHCL (Bedrock OLS + ESO)
```