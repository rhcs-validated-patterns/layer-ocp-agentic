data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "openai_pe" {
  name                 = "${var.cluster_name}-openai-pe"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.pe_subnet_prefix]
}

resource "azurerm_cognitive_account" "openai" {
  name                          = var.openai_account_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = var.openai_account_name
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.openai_model_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }
  sku {
    name     = var.openai_deployment_sku
    capacity = var.openai_capacity
  }
}

resource "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  name                 = "${var.cluster_name}-openai-dns"
  private_dns_zone_id  = azurerm_private_dns_zone.openai.id
  virtual_network_id   = data.azurerm_virtual_network.this.id
  registration_enabled = false
  tags                 = var.tags
}

resource "azurerm_private_endpoint" "openai" {
  name                = "${var.cluster_name}-openai-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.openai_pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.cluster_name}-openai-psc"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "openai-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.openai.id]
  }
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = var.key_vault_secret_name_api_key
  value        = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "endpoint" {
  name         = var.key_vault_secret_name_endpoint
  value        = "https://${azurerm_cognitive_account.openai.custom_subdomain_name}.openai.azure.com/"
  key_vault_id = var.key_vault_id
}