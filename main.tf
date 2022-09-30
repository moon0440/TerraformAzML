terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.25.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}


data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "moon-azml-rg" {
  name     = "moon-azml-rg"
  location = "Central US"
}

# Networking
resource "azurerm_virtual_network" "moon-azml-vnet" {
  name                = "moon-azml-vnet"
  resource_group_name = azurerm_resource_group.moon-azml-rg.name
  location            = azurerm_resource_group.moon-azml-rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "moon-azml-sn" {
  name                 = "moon-azml-sn"
  resource_group_name  = azurerm_resource_group.moon-azml-rg.name
  virtual_network_name = azurerm_virtual_network.moon-azml-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  enforce_private_link_service_network_policies = true
}
################## Nat Gw
resource "azurerm_nat_gateway" "moon-azml-ngw" {
  name                    = "moon-azml-ngw"
  location                = azurerm_resource_group.moon-azml-rg.location
  resource_group_name     = azurerm_resource_group.moon-azml-rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

# ACR
resource "azurerm_container_registry" "moon-azml-acr" {
  name                = "moonazmlacr"
  resource_group_name = azurerm_resource_group.moon-azml-rg.name
  location            = azurerm_resource_group.moon-azml-rg.location
  sku                 = "Premium"
  admin_enabled       = false
}
## ACR - PE
#resource "azurerm_private_endpoint" "moon-azml-acr-pe" {
#  name                = "moon-azml-acr-pe"
#  location            = azurerm_resource_group.moon-azml-rg.location
#  resource_group_name = azurerm_resource_group.moon-azml-rg.name
#  subnet_id           = azurerm_subnet.moon-azml-sn.id
#
#  private_service_connection {
#    name                           = "moon-azml-acr-pe-psc"
#    private_connection_resource_id = azurerm_container_registry.moon-azml-acr.id
#    is_manual_connection           = false
#    #    request_message                   = "PL"
#  }
#}

resource "azurerm_application_insights" "moon-azml-appin" {
  name                = "moon-azml-appin"
  location            = azurerm_resource_group.moon-azml-rg.location
  resource_group_name = azurerm_resource_group.moon-azml-rg.name
  application_type    = "web"
}

resource "azurerm_key_vault" "moon-azml-kv" {
  name                = "moon-azml-kv"
  location            = azurerm_resource_group.moon-azml-rg.location
  resource_group_name = azurerm_resource_group.moon-azml-rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
}

# Storage Account
resource "azurerm_storage_account" "moon-azml-sa" {
  name                     = "moonazmlsa"
  location                 = azurerm_resource_group.moon-azml-rg.location
  resource_group_name      = azurerm_resource_group.moon-azml-rg.name
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

#resource "azurerm_storage_container" "moon-azml-sc" {
#  name                  = "content"
#  storage_account_name  = azurerm_storage_account.moon-azml-sa.name
#  container_access_type = "private"
#}
#
#resource "azurerm_storage_blob" "moon-azml-sb" {
#  name                   = "my-awesome-content.zip"
#  storage_account_name   = azurerm_storage_account.moon-azml-sa.name
#  storage_container_name = azurerm_storage_container
#  type                   = "Block"
#  source                 = "some-local-file.zip"
#}


### Stro - PE
#resource "azurerm_private_endpoint" "moon-azml-acr-pe" {
#  name                = "moon-azml-acr-pe"
#  location            = azurerm_resource_group.moon-azml-rg.location
#  resource_group_name = azurerm_resource_group.moon-azml-rg.name
#  subnet_id           = azurerm_subnet.moon-azml-sn.id
#
#  private_service_connection {
#    name                              = "moon-azml-acr-pe-psc"
#    private_connection_resource_id  = azurerm_container_registry.moon-azml-acr.id
#    is_manual_connection              = false
##    request_message                   = "PL"
#  }
#}

resource "azurerm_machine_learning_workspace" "moon-azml-wksp" {
  name                    = "moon-azml-wksp"
  location                = azurerm_resource_group.moon-azml-rg.location
  resource_group_name     = azurerm_resource_group.moon-azml-rg.name
  application_insights_id = azurerm_application_insights.moon-azml-appin.id
  key_vault_id            = azurerm_key_vault.moon-azml-kv.id
  storage_account_id      = azurerm_storage_account.moon-azml-sa.id
  container_registry_id   = azurerm_container_registry.moon-azml-acr.id

  identity {
    type = "SystemAssigned"
  }
  # Args of use when using an Azure Private Link configuration
  public_network_access_enabled = false # default is true
  v1_legacy_mode_enabled        = true # default is false
  #  image_build_compute_name      = var.image_build_compute_name
  #  depends_on                    = [
  #    azurerm_private_endpoint.kv_ple,
  #    azurerm_private_endpoint.st_ple_blob,
  #    azurerm_private_endpoint.storage_ple_file,
  #    azurerm_private_endpoint.cr_ple,
  #    azurerm_subnet.snet-training
  #  ]

}
