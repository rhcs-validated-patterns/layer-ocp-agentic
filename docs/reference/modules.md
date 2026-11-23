# LLM modules

Root Terraform selects one module from `llm_backend`. Both modules read `platform.json` and contribute fields to the `agentic` output, which `make cluster.<profile>.apply` saves as `agentic.json`.

## `modules/azure`

Used when `llm_backend=azure` and `platform.installer.cloud` is `azure`.

Creates:

- A subnet on the installer VNet (`agentic_pe_subnet_prefix`, default `10.0.5.0/28`)
- An Azure OpenAI account restricted to private network, plus the model deployment from `openai_model_name` and `openai_model_version`
- A private endpoint and the `privatelink.openai.azure.com` zone
- Key Vault secrets for the API key and the endpoint

External Secrets syncs those into `openshift-lightspeed/lightspeed-azure-openai`. Lightspeed reads the key as `apitoken`.

Required contract fields: `key_vault_id`, `network.vnet_name`, `resource_group_name`.

## `modules/aws`

Used when `llm_backend=aws` and `platform.installer.cloud` is `aws`.

Creates:

- A Secrets Manager secret named `<cluster_name>-lightspeed-bedrock`
- A payload with `region`, `model_id`, and by default `aws_access_key_id` / `aws_secret_access_key`
- An IAM user allowed to call Bedrock (`provision_bedrock_iam_user`, default `true`)

Set `provision_bedrock_iam_user = false` and pass `bedrock_credentials_extra` to supply keys yourself.

External Secrets syncs the secret into `openshift-lightspeed/lightspeed-bedrock`. The installer IRSA role must be allowed to read that secret name (`additional_secrets` on the ROSA cluster).

Required contract fields: `aws_account_id`, `region`, `secrets_manager_role_arn`.

`bedrock_region` can differ from the cluster region when Mantle for the chosen model is in another region. `scripts/bedrock-discover.sh` lists models the Lightspeed credentials can call.

## Operators

The modules do not install Cluster Observability, Lightspeed, or Connectivity Link. `make cluster.<profile>.bootstrap` applies `gitops/overlays/public` (ARO) or uses the AWS overlay marker from `agentic.json` (`gitops_overlay: aws`) and then renders `OLSConfig` from `agentic.json`.
