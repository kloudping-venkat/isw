# Oracle Database Module Outputs

output "vm_id" {
  description = "ID of the Oracle database VM"
  value       = local.vm_id
}

output "vm_name" {
  description = "Name of the Oracle database VM"
  value       = var.vm_name
}

output "vm_private_ip" {
  description = "Private IP address of the Oracle database VM"
  value       = azurerm_network_interface.oracle_nic.private_ip_address
}

output "vm_computer_name" {
  description = "Computer name of the Oracle database VM"
  value       = var.vm_name
}

output "vm_admin_username" {
  description = "Administrator username for the Oracle database VM"
  value       = var.admin_username
  sensitive   = true
}

output "network_interface_id" {
  description = "ID of the network interface"
  value       = azurerm_network_interface.oracle_nic.id
}

output "network_security_group_id" {
  description = "ID of the network security group"
  value       = local.nsg_id
}

output "data_disk_ids" {
  description = "IDs of the data disks attached to the VM"
  value       = azurerm_managed_disk.oracle_data_disks[*].id
}

output "oracle_connection_details" {
  description = "Oracle database connection details"
  value = {
    hostname = azurerm_network_interface.oracle_nic.private_ip_address
    port     = "1521"
    sid      = var.oracle_sid
    pdb      = var.oracle_pdb
  }
  sensitive = true
}

output "key_vault_secrets" {
  description = "Key Vault secret names for database credentials"
  value = {
    admin_password_secret    = azurerm_key_vault_secret.db_admin_password.name
    connection_string_secret = azurerm_key_vault_secret.db_connection_string.name
  }
}

# VM Details for external reference
output "virtual_machine" {
  description = "Complete VM details in standardized format"
  value = {
    "${var.vm_name}" = {
      vm_id               = local.vm_id
      vm_name             = var.vm_name
      vm_computer_name    = var.vm_name
      vm_admin_username   = var.admin_username
      vm_private_ip       = azurerm_network_interface.oracle_nic.private_ip_address
      vm_size             = var.vm_size
      vm_os_type          = "Linux"
      vm_os_sku           = var.oracle_linux_version
      oracle_prep_enabled = var.enable_oracle_prep
      restored_from       = var.restore_from_snapshot ? "RestorePoint" : "New"
    }
  }
}

output "oracle_preparation_status" {
  description = "Oracle preparation method and testing information"
  value = {
    method_used = var.restore_from_snapshot ? "preserved-from-restore" : "cloud-init"
    enabled     = var.restore_from_snapshot ? false : var.enable_oracle_prep
    testing_commands = {
      quick_status      = "cat /tmp/oracle_prep_success"
      full_test         = "/tmp/cloud-init-oracle-test.sh"
      cloud_init_status = "sudo cloud-init status"
      oracle_user_check = "id oracle"
    }
    log_locations = {
      oracle_prep    = "/var/log/oracle_prep.log"
      cloud_init     = "/var/log/cloud-init-output.log (needs sudo)"
      success_marker = "/tmp/oracle_prep_success"
      config_summary = "/etc/oracle-release"
    }
    ssh_test_command = "ssh ${var.admin_username}@${azurerm_network_interface.oracle_nic.private_ip_address} 'cat /tmp/oracle_prep_success'"
    instructions     = var.restore_from_snapshot ? "VM restored from restore point. Oracle installation preserved from source VM." : (var.enable_oracle_prep ? "Oracle prep runs during VM boot. Test with: cat /tmp/oracle_prep_success (no sudo needed)" : "Oracle preparation disabled. Enable with enable_oracle_prep = true")
  }
}