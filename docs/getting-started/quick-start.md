# Quick start

Assumes the installer cluster is up, GitOps and External Secrets are installed, and `make cluster.<name>.platform` has written `platform.json`. If that is not true, start at [Choose an installer](../prerequisites/index.md).

Profiles in this repo:

| Copy from | Use when |
|-----------|----------|
| `clusters/public` | ARO HCP, Azure OpenAI |
| `clusters/rosa-public` | ROSA HCP, Bedrock |

`platform_json` is relative to the `terraform/` directory, not the repo root. Sibling checkouts sit next to this one in the examples below.

=== "ARO HCP"

    ```bash
    export ARO_HCP_ROOT=/path/to/validated-pattern-aro-hcp

    cp -r clusters/public clusters/my-agentic
    ```

    Edit `clusters/my-agentic/terraform.tfvars`:

    ```hcl
    platform_json = "../../validated-pattern-aro-hcp/clusters/<installer-profile>/platform.json"

    # llm_backend = "azure"   # default
    openai_model_name    = "gpt-5-mini"
    openai_model_version = "2025-08-07"
    openai_capacity      = 10
    ```

    ```bash
    make cluster.my-agentic.apply
    make cluster.my-agentic.bootstrap
    make cluster.my-agentic.verify
    ```

    `ARO_HCP_ROOT` selects `$ARO_HCP_ROOT/.kube/config` for bootstrap and verify, and refreshes `platform.json` before apply.

=== "ROSA HCP"

    ```bash
    export VP_TERRAFORM_ROSA_ROOT=/path/to/validated-pattern-terraform-rosa
    # Do not set ARO_HCP_ROOT. Login in the installer so ~/.kube/config is current:
    make -C "$VP_TERRAFORM_ROSA_ROOT" cluster.<name>.login

    cp -r clusters/rosa-public clusters/my-agentic
    ```

    Edit `clusters/my-agentic/terraform.tfvars`:

    ```hcl
    platform_json = "../../validated-pattern-terraform-rosa/clusters/<installer-profile>/platform.json"

    llm_backend = "aws"

    bedrock_region   = "ap-southeast-2"
    bedrock_model_id = "deepseek.v3.2"
    ```

    ```bash
    make cluster.my-agentic.apply
    make cluster.my-agentic.bootstrap
    make cluster.my-agentic.verify
    ```

    `VP_TERRAFORM_ROSA_ROOT` (or `ROSA_ROOT`) refreshes `platform.json` before apply. Bootstrap uses `~/.kube/config` unless you set `KUBECONFIG`.

Apply writes gitignored `clusters/<name>/agentic.json`. Bootstrap installs Cluster Observability, Lightspeed, and Connectivity Link, then applies `OLSConfig` from that file.

Destroy this profile before you destroy the installer cluster. Full sequence: [Agentic stack](../guides/agentic-stack.md).
