# EM Module Outputs

# Resource Group Outputs
output "rg_name" {
  description = "Name of the resource group"
  value       = local.rg_name
}

# Networking Outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = var.create_vnet ? module.networking[0].vnet_id : null
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = var.create_vnet ? module.networking[0].vnet_name : var.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = var.create_vnet ? module.networking[0].subnet_ids : {}
}

output "subnet_names" {
  description = "List of subnet names"
  value       = var.create_vnet ? module.networking[0].subnet_names : []
}

# Key Vault Outputs
output "key_vault_id" {
  description = "ID of the Key Vault (if created)"
  value       = var.create_key_vault ? module.keyvault[0].key_vault_id : null
}

output "key_vault_name" {
  description = "Name of the Key Vault (if created)"
  value       = var.create_key_vault ? module.keyvault[0].key_vault_name : null
}

output "key_vault_uri" {
  description = "URI of the Key Vault (if created)"
  value       = var.create_key_vault ? module.keyvault[0].key_vault_uri : null
}

# Compute Outputs
output "virtual_machines" {
  description = "Map of virtual machine information"
  value = {
    for vm_name, vm in module.compute : vm_name => {
      vm_id             = vm.vm_id
      vm_name           = vm.vm_name
      vm_private_ip     = vm.vm_private_ip
      vm_public_ip      = vm.vm_public_ip
      vm_admin_username = vm.vm_admin_username
      vm_computer_name  = vm.vm_computer_name
      vm_size           = vm.vm_size
    }
  }
}

# Temporary output for troubleshooting VM passwords - REMOVE IN PRODUCTION
output "vm_admin_passwords" {
  description = "TEMPORARY: Map of VM admin passwords for troubleshooting (REMOVE IN PRODUCTION)"
  value = {
    for vm_name, vm in module.compute : vm_name => vm.vm_admin_password
  }
  sensitive = true
}

# VPN Gateway Outputs
output "vpn_gateway_id" {
  description = "ID of the VPN Gateway (if created)"
  value       = var.create_vpn_gateway && contains(keys(var.subnets), "GatewaySubnet") ? module.vpn_gateway[0].vpn_gateway_id : null
}

output "vpn_gateway_name" {
  description = "Name of the VPN Gateway (if created)"
  value       = var.create_vpn_gateway && contains(keys(var.subnets), "GatewaySubnet") ? module.vpn_gateway[0].vpn_gateway_name : null
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway (if created)"
  value       = var.create_vpn_gateway && contains(keys(var.subnets), "GatewaySubnet") ? module.vpn_gateway[0].vpn_gateway_public_ip : null
}

output "vpn_client_config_secret" {
  description = "Key Vault secret containing VPN client configuration"
  value       = var.create_vpn_gateway && contains(keys(var.subnets), "GatewaySubnet") ? module.vpn_gateway[0].vpn_client_config_secret_name : null
}

output "vpn_client_address_space" {
  description = "VPN client address space"
  value       = var.create_vpn_gateway && contains(keys(var.subnets), "GatewaySubnet") ? module.vpn_gateway[0].vpn_client_address_space : null
}

# Application Gateway Outputs
output "application_gateway_id" {
  description = "ID of the Application Gateway (if created)"
  value       = var.create_application_gateway ? module.application_gateway[0].appgw_id : null
}

output "application_gateway_name" {
  description = "Name of the Application Gateway (if created)"
  value       = var.create_application_gateway ? module.application_gateway[0].appgw_name : null
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway (if created)"
  value       = var.create_application_gateway ? module.application_gateway[0].appgw_public_ip : null
}

output "application_gateway_identity_principal_id" {
  description = "Principal ID of the Application Gateway managed identity (if created)"
  value       = var.create_application_gateway ? azurerm_user_assigned_identity.appgw[0].principal_id : null
}

output "application_gateway_identity_id" {
  description = "ID of the Application Gateway managed identity (if created)"
  value       = var.create_application_gateway ? azurerm_user_assigned_identity.appgw[0].id : null
}
