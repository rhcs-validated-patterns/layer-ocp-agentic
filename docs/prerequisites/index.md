# Choose an installer

This repository installs the agentic operators and the cloud LLM resources they need. The cluster, the baseline GitOps install, and External Secrets Operator come from an installer.

Create the cluster with **one** of these repositories, finish that installer's bootstrap, and publish `platform.json`. Then come back here.

| | ARO HCP | ROSA HCP |
|--|---------|----------|
| Installer | [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) | [validated-pattern-terraform-rosa](https://github.com/rh-mobb/validated-pattern-terraform-rosa) |
| Docs | [ARO HCP site](https://rh-mobb.github.io/validated-pattern-aro-hcp/) | [ROSA HCP site](https://rh-mobb.github.io/validated-pattern-terraform-rosa/) |
| `platform.json` field `installer.cloud` | `azure` | `aws` |
| `llm_backend` in this repo | `azure` | `aws` |
| Example profile here | `clusters/public` or `clusters/aro-agentic` | `clusters/rosa-public` |
| LLM module | `modules/azure` | `modules/aws` |

The two installers publish the same portable core (`contract_version: 1`) and a cloud-specific extension block. This repo rejects a mismatch: Azure OpenAI will not plan against a ROSA contract, and Bedrock will not plan against an ARO contract. Details: [Platform contract](../guides/platform-contract.md).

## What the installer must already have done

1. `make cluster.<name>.apply` — cluster exists.
2. Baseline GitOps, including External Secrets Operator.
3. `make cluster.<name>.platform` — gitignored `clusters/<name>/platform.json`.
4. A kubeconfig this repo can use for `bootstrap` and `verify`.

=== "ARO HCP"

    ```bash
    export ARO_HCP_ROOT=/path/to/validated-pattern-aro-hcp
    make -C "$ARO_HCP_ROOT" cluster.<name>.apply
    make -C "$ARO_HCP_ROOT" cluster.<name>.kubeconfig
    make -C "$ARO_HCP_ROOT" cluster.<name>.external-auth
    make -C "$ARO_HCP_ROOT" cluster.<name>.bootstrap
    make -C "$ARO_HCP_ROOT" cluster.<name>.platform
    ```

    Kubeconfig lands in `$ARO_HCP_ROOT/.kube/config`. Later agentic commands keep `ARO_HCP_ROOT` set so bootstrap uses that file.

    Installer guide: [OpenShift 5 agentic stack](https://github.com/rh-mobb/validated-pattern-aro-hcp/blob/main/docs/guides/agentic-stack.md).

=== "ROSA HCP"

    ```bash
    export VP_TERRAFORM_ROSA_ROOT=/path/to/validated-pattern-terraform-rosa
    make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.apply
    make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.bootstrap
    make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.login
    make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.platform
    ```

    `make cluster.<name>.login` refreshes `~/.kube/config`. Do not set `ARO_HCP_ROOT` in this shell. Set `VP_TERRAFORM_ROSA_ROOT` (or `ROSA_ROOT`) so agentic `plan` and `apply` refresh `platform.json`.

    The cluster recipe needs Secrets Manager access for External Secrets (`enable_secrets_manager_iam = true`, which GitOps bootstrap turns on unless you disable it) and `additional_secrets` including `<cluster>-lightspeed-bedrock`. Installer contract: [Platform contract (ROSA)](https://github.com/rh-mobb/validated-pattern-terraform-rosa/blob/main/docs/guides/platform-contract.md).

## Next

[Account prerequisites](account.md) for quota and tools, then [Quick start](../getting-started/quick-start.md).
