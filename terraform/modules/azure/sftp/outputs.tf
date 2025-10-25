# EM SFTP Module Outputs

# ==============================================================================
# Storage Account Outputs
# ==============================================================================

output "storage_account_id" {
  description = "SFTP storage account resource ID"
  value       = var.create_sftp_storage ? azurerm_storage_account.main[0].id : null
}

output "storage_account_name" {
  description = "SFTP storage account name"
  value       = var.create_sftp_storage ? azurerm_storage_account.main[0].name : null
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = var.create_sftp_storage ? azurerm_storage_account.main[0].primary_blob_endpoint : null
}

output "storage_account_primary_dfs_endpoint" {
  description = "Primary Data Lake Storage Gen2 endpoint URL"
  value       = var.create_sftp_storage ? azurerm_storage_account.main[0].primary_dfs_endpoint : null
}

output "storage_account_identity_principal_id" {
  description = "Storage account managed identity principal ID"
  value       = var.create_sftp_storage && var.enable_managed_identity && length(azurerm_storage_account.main[0].identity) > 0 ? azurerm_storage_account.main[0].identity[0].principal_id : null
}

output "storage_containers" {
  description = "Map of created storage container names"
  value       = var.create_sftp_storage ? { for k, v in azurerm_storage_container.containers : k => v.name } : {}
}

# ==============================================================================
# Private Endpoint Outputs
# ==============================================================================

output "private_endpoint_id" {
  description = "Private endpoint resource ID"
  value       = var.create_private_endpoint ? azurerm_private_endpoint.sftp_pe[0].id : null
}

output "private_endpoint_ip_address" {
  description = "Private endpoint IP address"
  value       = var.create_private_endpoint ? azurerm_private_endpoint.sftp_pe[0].private_service_connection[0].private_ip_address : null
}

output "private_dns_zone_id" {
  description = "Private DNS zone resource ID"
  value       = var.create_private_dns_zone ? azurerm_private_dns_zone.blob[0].id : null
}

output "private_dns_zone_name" {
  description = "Private DNS zone name"
  value       = var.create_private_dns_zone ? azurerm_private_dns_zone.blob[0].name : null
}

# ==============================================================================
# NAT Gateway Outputs
# ==============================================================================

output "nat_gateway_id" {
  description = "NAT Gateway resource ID"
  value       = var.create_nat_gateway ? azurerm_nat_gateway.natgw[0].id : null
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP address"
  value       = var.create_nat_gateway ? azurerm_public_ip.natgw_pip[0].ip_address : null
}

output "nat_gateway_public_ip_id" {
  description = "NAT Gateway public IP resource ID"
  value       = var.create_nat_gateway ? azurerm_public_ip.natgw_pip[0].id : null
}

# ==============================================================================
# Network Security Group Outputs
# ==============================================================================

output "sftp_nsg_id" {
  description = "SFTP subnet NSG resource ID"
  value       = var.create_sftp_nsg ? azurerm_network_security_group.sftp_nsg[0].id : null
}

output "sftp_nsg_name" {
  description = "SFTP subnet NSG name"
  value       = var.create_sftp_nsg ? azurerm_network_security_group.sftp_nsg[0].name : null
}

# ==============================================================================
# Azure Firewall Outputs
# ==============================================================================

output "firewall_id" {
  description = "Azure Firewall resource ID"
  value       = var.create_firewall ? azurerm_firewall.main[0].id : null
}

output "firewall_name" {
  description = "Azure Firewall name"
  value       = var.create_firewall ? azurerm_firewall.main[0].name : null
}

output "firewall_public_ip" {
  description = "Azure Firewall public IP address"
  value       = var.create_firewall ? azurerm_public_ip.firewall_pip[0].ip_address : null
}

output "firewall_public_ip_id" {
  description = "Azure Firewall public IP resource ID"
  value       = var.create_firewall ? azurerm_public_ip.firewall_pip[0].id : null
}

# ==============================================================================
# Automation Account Outputs
# ==============================================================================

output "automation_account_id" {
  description = "Automation Account resource ID"
  value       = var.create_automation_account ? azurerm_automation_account.main[0].id : null
}

output "automation_account_name" {
  description = "Automation Account name"
  value       = var.create_automation_account ? azurerm_automation_account.main[0].name : null
}

output "automation_account_identity_principal_id" {
  description = "Automation Account managed identity principal ID"
  value       = var.create_automation_account && length(azurerm_automation_account.main[0].identity) > 0 ? azurerm_automation_account.main[0].identity[0].principal_id : null
}

output "automation_runbook_name" {
  description = "SFTP sync runbook name"
  value       = var.create_automation_account ? azurerm_automation_runbook.sftp_sync[0].name : null
}

output "automation_schedule_name" {
  description = "Automation schedule name"
  value       = var.create_automation_account && var.enable_automation_schedule ? azurerm_automation_schedule.sftp_sync_schedule[0].name : null
}

output "automation_private_endpoint_id" {
  description = "Automation Account private endpoint resource ID"
  value       = var.create_automation_account && var.create_automation_private_endpoint ? azurerm_private_endpoint.automation_pe[0].id : null
}

output "automation_private_endpoint_ip" {
  description = "Automation Account private endpoint IP address"
  value       = var.create_automation_account && var.create_automation_private_endpoint ? azurerm_private_endpoint.automation_pe[0].private_service_connection[0].private_ip_address : null
}

output "automation_private_dns_zone_id" {
  description = "Automation Account private DNS zone resource ID"
  value       = var.create_automation_account && var.create_automation_private_dns_zone ? azurerm_private_dns_zone.automation[0].id : null
}

output "automation_private_dns_zone_name" {
  description = "Automation Account private DNS zone name"
  value       = var.create_automation_account && var.create_automation_private_dns_zone ? azurerm_private_dns_zone.automation[0].name : null
}
