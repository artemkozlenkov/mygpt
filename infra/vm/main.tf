terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0.0"
    }
  }

  # Optional: Configure backend if needed
  # backend "azurerm" {
  #   resource_group_name  = "my-terraform-state"
  #   storage_account_name = "mystorageaccount"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}

# =============================================
# Variables
# =============================================

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string

}

variable "prefix" {
  description = "Prefix for naming resources"
  type        = string
  default     = "softawebit-vm"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "East US"
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = ["192.168.178.54/24"] # Replace with your IP range
}

# =============================================
# Resource Group
# =============================================

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location

  tags = {
    environment = "Terraform"
  }
}

# =============================================
# Virtual Network and Subnet
# =============================================

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "Terraform"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# =============================================
# Network Security Group
# =============================================

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "Terraform"
  }

  # Allow SSH
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22"]
    source_address_prefixes    = var.allowed_ssh_cidrs
    destination_address_prefix = "*"
  }

  # Deny All Inbound (Implicit Deny is Azure default, but can be explicitly defined)
  /*
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  */
}

# =============================================
# Network Interface
# =============================================

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Terraform"
  }
}

# =============================================
# Virtual Machine
# =============================================

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s" # Adjust size as needed

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  computer_name = "${var.prefix}-vm"

  disable_password_authentication = false

  provision_vm_agent = true

  tags = {
    environment = "Terraform"
  }
}

# =============================================
# RBAC: Assign Current User Administrator Role
# =============================================

# Alternatively, use the object ID from the client config
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "admin_role" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor" # Adjust role as needed
  principal_id         = data.azurerm_client_config.current.object_id
}

# =============================================
# Outputs
# =============================================


output "vm_username" {
  description = "Administrator username for the VM."
  value       = var.admin_username
}


output "rbac_role_assignment_id" {
  description = "RBAC Role Assignment ID for the current user."
  value       = azurerm_role_assignment.admin_role.id
}