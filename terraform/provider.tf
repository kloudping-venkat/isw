terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
  #use_msi = true
}

provider "azapi" {
  # Uses same authentication as azurerm provider
}
