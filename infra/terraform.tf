terraform {
  required_version = "1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.16.0"

    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-ml-production"
    storage_account_name = "mlprodstorageacct"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}
