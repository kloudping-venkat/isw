# VNet Peering Module for Azure AD Domain Services
# Creates bidirectional peering between local VNet and Azure AD DS VNet

# Data source to get the remote Azure AD DS VNet
data "azurerm_virtual_network" "aadds_vnet" {
  name                = var.aadds_vnet_name
  resource_group_name = var.aadds_vnet_resource_group
}

# Data source to get the local VNet
data "azurerm_virtual_network" "local_vnet" {
  name                = var.local_vnet_name
  resource_group_name = var.local_resource_group_name
}

# Peering from Hub VNet to Azure AD DS VNet (for hub-spoke architecture)
resource "azurerm_virtual_network_peering" "local_to_aadds" {
  name                      = "${var.local_vnet_name}-to-${var.aadds_vnet_name}"
  resource_group_name       = var.local_resource_group_name
  virtual_network_name      = var.local_vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.aadds_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true # Hub allows transit to spoke
  use_remote_gateways          = false

  depends_on = [data.azurerm_virtual_network.local_vnet, data.azurerm_virtual_network.aadds_vnet]
}

# Peering from Azure AD DS VNet to Hub VNet (bidirectional)
resource "azurerm_virtual_network_peering" "aadds_to_local" {
  name                      = "${var.aadds_vnet_name}-to-${var.local_vnet_name}"
  resource_group_name       = var.aadds_vnet_resource_group
  virtual_network_name      = var.aadds_vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.local_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true # Allow transit from AADDS through hub to spoke
  use_remote_gateways          = false

  depends_on = [data.azurerm_virtual_network.local_vnet, data.azurerm_virtual_network.aadds_vnet]
}