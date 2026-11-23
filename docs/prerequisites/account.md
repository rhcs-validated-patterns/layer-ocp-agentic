# Account prerequisites

The cluster installer owns subscription and account bootstrap. This page is only what **this** repository adds on top of a finished installer cluster.

Shared tools:

- Terraform >= 1.5
- `make`, `jq`, `oc`
- Python 3.12 if you preview these docs (`make docs-preview`)

The cluster must be **OpenShift 5.0+** with External Secrets Operator already installed by the installer bootstrap.

## Azure (ARO HCP, `llm_backend=azure`)

- Cognitive Services quota for the OpenAI model in `openai_model_name` / `openai_model_version` in the cluster region.
- **Contributor** on the customer resource group.
- **Key Vault Secrets Officer** (or equivalent) on the installer Key Vault. Terraform writes the API key and endpoint there; External Secrets reads them.
- Permission to create a subnet and a private endpoint on the installer VNet. The default prefix is `network.reserved.agentic_pe_subnet_prefix` (`10.0.5.0/28` unless the installer reserved something else).

`platform.json` must include `key_vault_id`, `network.vnet_name`, and `resource_group_name`, and `installer.cloud` must be `azure`.

## AWS (ROSA HCP, `llm_backend=aws`)

- Bedrock model access in the region you set as `bedrock_region` (defaults to the cluster region).
- `platform.json` must include `aws_account_id`, `region`, and `secrets_manager_role_arn`. `installer.cloud` must be `aws`.
- Installer recipe: `enable_secrets_manager_iam = true`.
- Installer `additional_secrets` includes `<cluster_name>-lightspeed-bedrock` so the External Secrets IRSA role can `GetSecretValue`. The name is predictable; you can set it before this repo creates the secret.
- Default module behavior creates an IAM user and access key for Lightspeed (`provision_bedrock_iam_user = true`). Set that to `false` and pass `bedrock_credentials_extra` when you bring your own keys.

## Operators only

`llm_backend = "none"` skips cloud LLM resources. You still need the cluster and External Secrets. Write a complete `agentic.json` yourself before `make cluster.<name>.bootstrap`.

## Destroy order

Destroy this stack before the cluster.

```bash
# this checkout
make cluster.<name>.destroy

# then the installer that created the cluster
make -C "$ARO_HCP_ROOT" cluster.<name>.destroy
# or
make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.destroy
```
