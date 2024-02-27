resource "azurerm_virtual_network" "main" {
  name                = module.naming.virtual_network.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = var.spec.virtual_network.address_space
}

resource "azurerm_subnet" "default" {
  name                 = module.naming.subnet.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [
    cidrsubnet(var.spec.virtual_network.address_space.0, 2, 0),
    cidrsubnet(var.spec.virtual_network.address_space.1, local.ipv6_mask_bits, 0)
  ]
}

resource "azurerm_subnet" "main" {
  for_each             = var.spec.zones
  name                 = "${module.naming.subnet.name}-zone-${each.value}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [
    cidrsubnet(var.spec.virtual_network.address_space.0, 2, tonumber(each.value)),
    cidrsubnet(var.spec.virtual_network.address_space.1, local.ipv6_mask_bits, tonumber(each.value))
  ]
}

resource "azurerm_public_ip_prefix" "ipv4" {
  name                = "${module.naming.public_ip_prefix.name}-ipv4"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  ip_version          = "IPv4"
  sku                 = "Standard"
  prefix_length       = 28
  zones               = var.spec.zones
}

resource "azurerm_public_ip_prefix" "ipv6" {
  name                = "${module.naming.public_ip_prefix.name}-ipv6"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  ip_version          = "IPv6"
  sku                 = "Standard"
  prefix_length       = 124
  zones               = var.spec.zones
}

resource "azurerm_network_security_group" "main" {
  name                = module.naming.network_security_group.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowHttpIn"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "80"
    protocol                   = "Tcp"
    priority                   = 100
  }

  security_rule {
    name                       = "AllowHttpsIn"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "443"
    protocol                   = "Tcp"
    priority                   = 110
  }
}

resource "azurerm_subnet_network_security_group_association" "default" {
  network_security_group_id = azurerm_network_security_group.main.id
  subnet_id                 = azurerm_subnet.default.id
}

resource "azurerm_subnet_network_security_group_association" "main" {
  for_each                  = var.spec.zones
  network_security_group_id = azurerm_network_security_group.main.id
  subnet_id                 = azurerm_subnet.main[each.value].id
}
