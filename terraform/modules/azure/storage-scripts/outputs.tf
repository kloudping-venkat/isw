# Storage Scripts Module Outputs

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.scripts_storage.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.scripts_storage.id
}

output "container_name" {
  description = "Name of the blob container"
  value       = azurerm_storage_container.scripts_container.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.scripts_storage.primary_blob_endpoint
}

output "script_urls" {
  description = "URLs of uploaded PowerShell scripts"
  value = {
    provisioning_disks_app = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/Provisioning_disks_APP.ps1"
    provisioning_disks_web = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/Provisioning_disks_WEB.ps1"
    bofa_domain_join       = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/BOFA_domain_join.ps1"
    app_server_roles       = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/app-server-roles.ps1"
    web_server_roles       = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/web-server-roles.ps1"
    sentinelone_install    = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/SentinelOne_install.ps1"
    tanium_install_script  = "${azurerm_storage_account.scripts_storage.primary_blob_endpoint}${azurerm_storage_container.scripts_container.name}/Tanium_install_script.ps1"
  }
}