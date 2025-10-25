# Storage Account Module for PowerShell Scripts
# Completely public storage account with no access restrictions

# Storage Account
resource "azurerm_storage_account" "scripts_storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Make storage account completely public
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = true
  shared_access_key_enabled       = true

  # No network restrictions - allow from anywhere
  # network_rules block is completely omitted for full public access

  tags = var.tags
}

# Storage Container
resource "azurerm_storage_container" "scripts_container" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.scripts_storage.name
  container_access_type = "blob" # Public read access for script downloads
}

# Upload PowerShell scripts from git repository
resource "azurerm_storage_blob" "configure_vm" {
  name                   = "configure-vm.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.module}/../compute/scripts/configure-vm.ps1"
  content_md5            = filemd5("${path.module}/../compute/scripts/configure-vm.ps1")
}

resource "azurerm_storage_blob" "provisioning_disks_app" {
  name                   = "Provisioning_disks_APP.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/Provisioning_disks_APP.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/Provisioning_disks_APP.ps1")
}

resource "azurerm_storage_blob" "provisioning_disks_web" {
  name                   = "Provisioning_disks_WEB.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/Provisioning_disks_WEB.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/Provisioning_disks_WEB.ps1")
}

resource "azurerm_storage_blob" "bofa_domain_join" {
  name                   = "BOFA_domain_join.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/BOFA_domain_join.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/BOFA_domain_join.ps1")
}

resource "azurerm_storage_blob" "app_server_roles" {
  name                   = "app-server-roles.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/app-server-roles.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/app-server-roles.ps1")
}

resource "azurerm_storage_blob" "web_server_roles" {
  name                   = "web-server-roles.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/web-server-roles.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/web-server-roles.ps1")
}

resource "azurerm_storage_blob" "sentinelone_install" {
  name                   = "SentinelOne_install.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/SentinelOne_install.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/SentinelOne_install.ps1")
}

resource "azurerm_storage_blob" "tanium_install_script" {
  name                   = "Tanium_install_script.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/Tanium_install_script.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/Tanium_install_script.ps1")
}

resource "azurerm_storage_blob" "gmsa_configuration" {
  name                   = "gMSA_configuration.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/gMSA_configuration.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/gMSA_configuration.ps1")
}

resource "azurerm_storage_blob" "oracle_client_install" {
  name                   = "Oracle_client_install.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/Oracle_client_install.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/Oracle_client_install.ps1")
}

resource "azurerm_storage_blob" "datadog_gpg_install" {
  name                   = "Datadog_GPG_install.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/Datadog_GPG_install.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/Datadog_GPG_install.ps1")
}

resource "azurerm_storage_blob" "bofa_master_deploy" {
  name                   = "BOFA_Master_Deploy.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts_container.name
  type                   = "Block"
  source                 = "${path.root}/${var.scripts_path}/BOFA_Master_Deploy.ps1"
  content_md5            = filemd5("${path.root}/${var.scripts_path}/BOFA_Master_Deploy.ps1")
}