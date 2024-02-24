module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
  suffix  = [var.spec.project, var.spec.location]
}

data "azuread_client_config" "main" {}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = var.spec.location
}
