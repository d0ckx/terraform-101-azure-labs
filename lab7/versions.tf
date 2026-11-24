terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.3.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }
}

provider "azapi" {
}

provider "azurerm" {
  features {}
}