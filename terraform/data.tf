data "azuread_client_config" "main" {}

data "terraform_remote_state" "meta" {
  backend = "remote"
  config = {
    organization = "Exatron"
    workspaces = {
      name = "meta"
    }
  }
}

data "azurerm_resource_group" "meta" {
  name = data.terraform_remote_state.meta.outputs.resource_group_name
}

data "azurerm_user_assigned_identity" "meta" {
  name                = data.terraform_remote_state.meta.outputs.identity_name
  resource_group_name = data.azurerm_resource_group.meta.name
}
