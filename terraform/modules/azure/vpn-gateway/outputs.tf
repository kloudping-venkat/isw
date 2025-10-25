# VPN Gateway Module Outputs

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.id
}

output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.name
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway_pip.ip_address
}

output "vpn_gateway_public_ip_secondary" {
  description = "Secondary public IP address of the VPN Gateway (if active-active)"
  value       = var.active_active ? azurerm_public_ip.vpn_gateway_pip_secondary[0].ip_address : null
}

output "vpn_client_address_space" {
  description = "VPN client address space"
  value       = var.vpn_client_address_space
}

output "vpn_client_config_secret_name" {
  description = "Name of the Key Vault secret containing VPN client configuration"
  value       = azurerm_key_vault_secret.vpn_client_config.name
}

output "vpn_client_config_secret_id" {
  description = "ID of the Key Vault secret containing VPN client configuration"
  value       = azurerm_key_vault_secret.vpn_client_config.id
}

output "aad_configuration" {
  description = "Azure AD configuration for VPN authentication"
  value = {
    tenant_id = var.aad_tenant_id
    audience  = var.aad_audience
    issuer    = var.aad_issuer
  }
  sensitive = true
}