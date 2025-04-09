# Terraform configuration for Azure Storage Account

provider "azurerm" {
  features {}
}

# Add variables for resource group name, location, and storage account name
variable "resource_group_name" {
  description = "The name of the resource group"
  default     = "terraform_state_rg"
}

variable "location" {
  description = "The location of the resources"
  default     = "West Europe"
}

variable "storage_account_name" {
  description = "The name of the storage account"
  default     = "akrpltfstore"
}

resource "azurerm_resource_group" "state_store_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "state_store" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.state_store_rg.name
  location                 = azurerm_resource_group.state_store_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "TerraformState"
  }
}

resource "azurerm_storage_container" "tf_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state_store.name
  container_access_type = "private"
}

# Output the storage account name, container name, and generate a SAS token for the container
output "storage_account_name" {
  value = azurerm_storage_account.state_store.name
}

output "container_name" {
  value = azurerm_storage_container.tf_state.name
}