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
  }
}

provider "azurerm" {
  features {}
  tenant_id       = var.spec.tenant_id
  subscription_id = var.spec.subscription_id
}
