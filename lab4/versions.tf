terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-dev"
    storage_account_name = "stih5cqm9o7b"
    container_name       = "tfstate"
    key                  = "devops-dev"
  }
}

provider "azurerm" {
  features {}

  subscription_id = "3070a477-1bd0-41d0-83ca-f2f0fe7cf9e7"
}