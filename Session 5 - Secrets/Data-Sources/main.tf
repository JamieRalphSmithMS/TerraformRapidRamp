terraform {
  required_version = "~>1.2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }

    /*backend "azurerm" {
      resource_group_name  = "tfstate"
      storage_account_name = "<storage_account_name>"
      container_name       = "tfstate"
      key                  = "terraform.tfstate"
    }https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage?tabs=powershell*/
  }
}

provider "azurerm" {
  features {}

  subscription_id = "0f87398b-35e8-4c05-afe6-e7f65a7dde53"
  tenant_id       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
}

data "azurerm_key_vault" "key_vault" {
  name = "inc-kv-001"
  resource_group_name = ""
}


data "azurerm_key_vault_secret" "admin_password" {
  name = "admin-password"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "azurerm_resource_group" "example" {
  name     = "myResourceGroup"
  location = "eastus"
}

resource "azurerm_virtual_network" "example" {
  name                = "terraform-rr-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "example" {
  name                  = "terraform-rr-vm"
  location              = "eastus"  # Modify to your desired location
  resource_group_name   = "myResourceGroup"
  vm_size               = "Standard_DS2_v2"
  network_interface_ids = [azurerm_network_interface.example.id]
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 30
  }

  os_profile {
    computer_name  = "example-vm"
    admin_username = "admin"
    admin_password = data.azurerm_key_vault_secret.admin_password.value
  }
}