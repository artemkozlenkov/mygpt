terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state in Azure Blob Storage (pre-provisioned bootstrap infra).
  backend "azurerm" {
    resource_group_name  = "rg-mygpt-tfstate"
    storage_account_name = "stmygpttfstate"
    container_name       = "tfstate"
    key                  = "infra-azure.tfstate"
  }
}

# Auth comes from the authenticated az CLI session (az login) — no keys here.
provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}
