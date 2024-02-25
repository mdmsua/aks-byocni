module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
  suffix  = [var.spec.project, var.spec.location]
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = var.spec.location
}
