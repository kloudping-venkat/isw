# VNet Peering Module Outputs

output "local_to_aadds_peering_id" {
  description = "Resource ID of the local to Azure AD DS peering"
  value       = azurerm_virtual_network_peering.local_to_aadds.id
}

output "aadds_to_local_peering_id" {
  description = "Resource ID of the Azure AD DS to local peering"
  value       = azurerm_virtual_network_peering.aadds_to_local.id
}

output "aadds_vnet_address_space" {
  description = "Address space of the Azure AD DS VNet"
  value       = data.azurerm_virtual_network.aadds_vnet.address_space
}

output "peering_status" {
  description = "Status of the peering connections"
  value = {
    local_to_aadds = azurerm_virtual_network_peering.local_to_aadds.id
    aadds_to_local = azurerm_virtual_network_peering.aadds_to_local.id
  }
}