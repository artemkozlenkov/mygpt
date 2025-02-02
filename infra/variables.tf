
variable "location" {
  type        = string
  description = "Location for resources"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "hub_name" {
  type        = string
  description = "Name of the Azure Machine Learning Workspace"
}

variable "key_vault_name" {
  type        = string
  description = "Name of the Azure Key Vault"
}

variable "storage_account_name" {
  type        = string
  description = "Name of the Azure Storage Account"
}


variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for resources"
}

variable "application_insights_name" {
  type        = string
  description = "Name of the Azure Application Insights resource"
}
