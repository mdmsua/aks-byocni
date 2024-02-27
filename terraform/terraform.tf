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

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  tenant_id            = var.spec.tenant_id
  subscription_id      = var.spec.subscription_id
  use_cli              = false
  use_oidc             = true
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azurerm" {
  features {}
  alias                = "meta"
  tenant_id            = var.spec.tenant_id
  subscription_id      = data.terraform_remote_state.meta.outputs.subscription_id
  use_cli              = false
  use_oidc             = true
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azuread" {
  tenant_id            = var.spec.tenant_id
  use_cli              = false
  use_oidc             = true
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azapi" {
  tenant_id            = var.spec.tenant_id
  subscription_id      = var.spec.subscription_id
  use_cli              = false
  use_oidc             = true
  client_id            = file(var.tfc_azure_dynamic_credentials.default.client_id_file_path)
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

variable "tfc_azure_dynamic_credentials" {
  type = object({
    default = object({
      client_id_file_path  = string
      oidc_token_file_path = string
    })
    aliases = map(object({
      client_id_file_path  = string
      oidc_token_file_path = string
    }))
  })
}
