# Networking Outputs from Azure VNet Module

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.vnet.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = module.vnet.vnet_subnets_name_id
}

output "subnet_names" {
  description = "List of subnet names"
  value       = module.vnet.vnet_subnets
}

output "nsg_ids" {
  description = "Map of NSG names to their IDs"
  value       = { for k, v in azurerm_network_security_group.subnet_nsg : k => v.id }
}