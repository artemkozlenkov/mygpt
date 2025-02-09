provider "azurerm" {
  features {
  }
  environment = "public"
  use_msi     = false
  use_cli     = true
  use_oidc    = false
}
