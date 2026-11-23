# AWS LLM module (Bedrock / ROSA)

Consumes **`platform.json`** from [`vp-terraform-rosa`](https://github.com/rh-mobb/validated-pattern-terraform-rosa) (`make cluster.<name>.platform`).

## What it does today

- Writes a **Secrets Manager** secret `${cluster_name}-lightspeed-bedrock` with Bedrock `region`, `model_id`, and (by default) **`aws_access_key_id` / `aws_secret_access_key`** for **External Secrets Operator** on the cluster.
- Optionally creates a scoped **IAM user** (`provision_bedrock_iam_user`, default `true`) with `bedrock:InvokeModel*` for dev/test; set `false` and use `bedrock_credentials_extra` for customer keys.
- Emits **`agentic.json`** fields for `scripts/gitops-bootstrap.sh` (Bedrock `OLSConfig`, Bedrock ExternalSecret).

## Prerequisites (installer recipe)

- `enable_secrets_manager_iam = true` so `platform.json` includes `secrets_manager_role_arn`.
- `additional_secrets = ["<cluster>-lightspeed-bedrock"]` on the ROSA installer (or re-apply installer after this module creates the secret) so ESO can `GetSecretValue`.
- GitOps bootstrap on the cluster (ESO + `ClusterSecretStore` for AWS Secrets Manager).
- Bedrock model access enabled in the AWS account/region.

## Inputs

| Variable | Source |
|----------|--------|
| `cluster_name`, `region`, `aws_account_id` | `platform.json` |
| `bedrock_model_id` | `terraform.tfvars` |

See [platform contract](../../docs/guides/platform-contract.md).