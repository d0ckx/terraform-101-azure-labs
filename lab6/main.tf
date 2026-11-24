resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_location
}

//public ip to access VM
# resource "azurerm_public_ip" "vm1" {
#   name                = "pip-${var.application_name}-${var.environment_name}-vm1"
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   allocation_method   = "Static"
# }

//subnet reference for NIC to connect to
data "azurerm_subnet" "bravo" {
  name                 = "snet-bravo"
  virtual_network_name = "vnet-network-dev"
  resource_group_name  = "rg-network-dev"
}

// NIC for the VM
resource "azurerm_network_interface" "vm1" {
  name                = "nic-${var.application_name}-${var.environment_name}-vm1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "public"
    subnet_id                     = data.azurerm_subnet.bravo.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.vm1.id
  }
}

//provide SSH key to connect to VM
resource "tls_private_key" "vm1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

// Placing the SSH key into KeyVault to access the VM via Bastion
// getting the Keyvault data source for the keyvault id
data "azurerm_key_vault" "main" {
  name                = "kv-devops-dev-qlk1bv"
  resource_group_name = "rg-devops-dev"
}

// creating a key vault secret containing the ssh private key
resource "azurerm_key_vault_secret" "vm1-ssh-private" {
  name         = "vm1-ssh-private"
  value        = tls_private_key.vm1.private_key_pem
  key_vault_id = data.azurerm_key_vault.main.id
}

// creating a key vault secret containing the ssh public key
resource "azurerm_key_vault_secret" "vm1-ssh-public" {
  name         = "vm1-ssh-public"
  value        = tls_private_key.vm1.public_key_openssh
  key_vault_id = data.azurerm_key_vault.main.id
}

//VM itself
resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "vm1${var.application_name}${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D2als_v6"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm1.id,
  ]
  priority        = "Spot"
  eviction_policy = "Delete"
  max_bid_price   = -1

  // assign  identity for the entra id login using the extension
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vm1.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

// VM extension used for entra ID connection into the VM
resource "azurerm_virtual_machine_extension" "entra_id_login" {
  name                 = "${azurerm_linux_virtual_machine.vm1.name}-AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm1.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
}

// get my user attributes to assign it permissions for the VM
data "azurerm_client_config" "current" {
}

// assign my user the permissions needed to access the VM via entra
resource "azurerm_role_assignment" "entr_id_user_login" {
  scope = azurerm_linux_virtual_machine.vm1.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id = azuread_group.remote_access_users.object_id
}

