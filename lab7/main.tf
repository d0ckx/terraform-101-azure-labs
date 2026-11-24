
// create rg resource with azapi provider
resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2021-04-01"
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_location

  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
}

// get the current env data for the subscription id used in the rg resource
data "azapi_client_config" "current" {

}

// public ip address
resource "azapi_resource" "vm_pip" {
  type      = "Microsoft.Network/publicIPAddresses@2024-05-01"
  name      = "pip-${var.application_name}-${var.environment_name}"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id

  body = {
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
    }

    sku = {
      name = "Standard"
    }
  }
}

/* 
quick recreation of a subnet that we want to access 
using a data source but I already deleted to save costs
*/
resource "azurerm_virtual_network" "main" {
  name                = "vnet-network-dev"
  location            = var.primary_location
  resource_group_name = azapi_resource.rg.name
  address_space       = ["10.39.0.0/22"]
}

resource "azurerm_subnet" "bravo" {
  name                 = "snet-bravo"
  resource_group_name  = azapi_resource.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.39.1.0/24"]
}

/* 
getting a datasource using the azapi provider
we will use these later to create a NIC for our VM
*/
data "azapi_resource" "vnet" {
  name      = "vnet-network-dev"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
}

data "azapi_resource" "subnet_bravo" {
  name      = "snet-bravo"
  parent_id = data.azapi_resource.vnet.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"

  response_export_values = ["name"]
}

//create a NIC for my VM
resource "azapi_resource" "vm1_nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "nic-${var.application_name}-${var.environment_name}"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id

  body = {
    properties = {
      ipConfigurations = [
        {
          name = "public"

          properties = {
            privateIPAllocationMethod = "Dynamic"

            publicIPAddress = {
              id = azapi_resource.vm_pip.id
            }

            subnet = {
              id = data.azapi_resource.subnet_bravo.id
            }
          }
        }
      ]
    }
  }
}


//SSH Key
resource "tls_private_key" "vm1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

/* 
quick recreation of the KV that we want to access 
using a data source but I already deleted to save costs
*/
resource "random_string" "keyvault_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.application_name}-${var.environment_name}-${random_string.keyvault_suffix.result}"
  location            = azapi_resource.rg.location
  resource_group_name = azapi_resource.rg.name

  tenant_id = data.azapi_client_config.current.tenant_id
  sku_name  = "standard"

  enable_rbac_authorization = true
}

resource "azapi_resource" "vm1_ssh_private" {
  type      = "Microsoft.KeyVault/vaults/secrets@2024-12-01-preview"
  name      = "azapivm-ssh-private"
  parent_id = azurerm_key_vault.main.id
  schema_validation_enabled = false

  body = {
    properties = {
      value = tls_private_key.vm1.private_key_pem
    }
  }
  lifecycle {
    ignore_changes = [ location ]
  }
}

resource "azapi_resource" "vm1_ssh_public" {
  type      = "Microsoft.KeyVault/vaults/secrets@2024-12-01-preview"
  name      = "azapivm-ssh-public"
  parent_id = data.azapi_resource.keyvault.id

  body = {
    properties = {
      value = tls_private_key.vm1.public_key_openssh
    }
  }
}