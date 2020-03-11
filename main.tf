# Configure the Microsoft Azure Provider
# http://terraform.io/docs/providers/azurerm/index.html
provider "azurerm" {

  version = "=2.0.0"

  features {}

  # More information on the authentication methods supported by
  # the AzureRM Provider can be found here:


  subscription_id = var.az_subscription1
  client_id       = var.az_client_id1
  client_secret   = var.az_client_pw1
  tenant_id       = var.az_tenant1
}

# Create a resource group
resource "azurerm_resource_group" "example" {
  name     = "ResourceG1"
  location = "East US"
}


# Create a virtual network in the production-resources resource group
resource "azurerm_virtual_network" "test" {
  name                = "production-network"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["172.19.0.0/16"]
}


resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefix       = "172.19.2.0/24"
}


resource "azurerm_public_ip" "myterraformpublicip" {
  name                         = "myPublicIP"
  location                     = "eastus"
  resource_group_name          = azurerm_resource_group.example.name
  allocation_method            = "Dynamic"

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "myNetworkSecurityGroup"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform Demo"
  }
}


resource "azurerm_network_interface" "myterraformnic" {
  name                        = "myNIC"
  location                    = "eastus"
  resource_group_name         = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}


resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.example.name
  }

  byte_length = 8
}



resource "azurerm_storage_account" "mystorageaccount" {
  name                        = "diag${random_id.randomId.hex}"
  resource_group_name         = azurerm_resource_group.example.name
  location                    = "eastus"
  account_replication_type    = "LRS"
  account_tier                = "Standard"

  tags = {
    environment = "Terraform Demo"
  }
}


resource "azurerm_linux_virtual_machine" "myterraformvm" {
  name                  = "BastionVM1"
  location              = "eastus"
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  size                  = "Standard_B1s"

  os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = "bastion1"
  admin_username = "eugeneus"
  disable_password_authentication = true

  admin_ssh_key {
    username       = "eugeneus"
    public_key = file("~/.ssh/kea1.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }

  tags = {
    environment = "Terraform Demo"
  }

    source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

