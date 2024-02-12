terraform {
  backend "remote" {
    organization = "Exatron"

    workspaces {
      prefix = "byocni-"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>1.0"
    }
  }
}
