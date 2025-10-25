# EM Infrastructure Module - Version Configuration
# This module orchestrates Azure modules to create EM-specific infrastructure patterns

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Module Dependencies
# This module uses the following Azure module version
locals {
  azure_modules_version = "1.0.0" # References modules/azure version
}
