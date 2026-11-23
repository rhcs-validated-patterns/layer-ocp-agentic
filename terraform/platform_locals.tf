locals {
  platform = jsondecode(file(var.platform_json))

  platform_installer_cloud = try(local.platform.installer.cloud, "azure")

  pe_prefix = coalesce(
    var.pe_subnet_prefix != "" ? var.pe_subnet_prefix : null,
    try(local.platform.network.reserved.agentic_pe_subnet_prefix, null),
    "10.0.5.0/28"
  )

  openai_account_name = replace(
    substr(
      lower("${local.platform.cluster_name}${var.openai_account_name_suffix}"),
      0,
      24
    ),
    "-",
    ""
  )
}

resource "terraform_data" "platform_llm" {
  lifecycle {
    precondition {
      condition = var.llm_backend != "azure" || (
        try(local.platform.key_vault_id, null) != null &&
        try(local.platform.network.vnet_name, null) != null &&
        try(local.platform.resource_group_name, null) != null
      )
      error_message = "llm_backend=azure requires platform.json from an ARO installer (key_vault_id, network.vnet_name, resource_group_name)."
    }

    precondition {
      condition     = var.llm_backend != "azure" || local.platform_installer_cloud == "azure"
      error_message = "llm_backend=azure requires platform.installer.cloud=azure (got '${local.platform_installer_cloud}')."
    }

    precondition {
      condition = var.llm_backend != "aws" || (
        try(local.platform.aws_account_id, null) != null &&
        try(local.platform.region, null) != null &&
        try(local.platform.secrets_manager_role_arn, null) != null
      )
      error_message = "llm_backend=aws requires platform.json from vp-terraform-rosa (aws_account_id, region, secrets_manager_role_arn; enable enable_secrets_manager_iam on the cluster recipe)."
    }

    precondition {
      condition     = var.llm_backend != "aws" || local.platform_installer_cloud == "aws"
      error_message = "llm_backend=aws requires platform.installer.cloud=aws (got '${local.platform_installer_cloud}')."
    }
  }
}