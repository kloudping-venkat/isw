# EM Compute Module Outputs
# Outputs for Windows Server resources

output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_windows_virtual_machine.vm.name
}

output "vm_private_ip" {
  description = "Private IP address of the virtual machine"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP address of the virtual machine (if enabled)"
  value       = var.enable_public_ip ? azurerm_public_ip.vm_public_ip[0].ip_address : null
}

output "vm_network_interface_id" {
  description = "ID of the network interface"
  value       = azurerm_network_interface.vm_nic.id
}

output "vm_admin_username" {
  description = "Administrator username for the VM"
  value       = azurerm_windows_virtual_machine.vm.admin_username
}

output "vm_computer_name" {
  description = "Computer name of the VM"
  value       = azurerm_windows_virtual_machine.vm.computer_name
}

output "vm_size" {
  description = "Size of the virtual machine"
  value       = azurerm_windows_virtual_machine.vm.size
}

output "key_vault_secret_id" {
  description = "ID of the Key Vault secret containing the VM password"
  value       = azurerm_key_vault_secret.vm_password.id
  sensitive   = true
}

# Temporary output for troubleshooting - REMOVE IN PRODUCTION
output "vm_admin_password" {
  description = "TEMPORARY: Admin password for troubleshooting (REMOVE IN PRODUCTION)"
  value       = random_password.vm_password.result
  sensitive   = true
}

output "vm_identity_principal_id" {
  description = "Principal ID of the VM's system-assigned managed identity"
  value       = azurerm_windows_virtual_machine.vm.identity[0].principal_id
}

output "data_disks_count" {
  description = "DEBUG: Number of data disks configured"
  value       = length(var.data_disks)
}

output "data_disks_config" {
  description = "DEBUG: Data disks configuration"
  value       = var.data_disks
}