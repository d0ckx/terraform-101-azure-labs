
//main rg
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_region
}

//generate a random string resource for the storage account
resource "random_string" "suffix" {
  length  = 10
  upper   = false
  special = false
}

//storage account for the terraform statefile 
resource "azurerm_storage_account" "main" {
  name                     = "st${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


//blob storage container for the state file
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}