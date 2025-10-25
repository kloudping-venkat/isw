# EM Key Vault Module
# Creates Azure Key Vault for secure secret storage

# Get current client configuration
data "azurerm_client_config" "current" {}

# Random suffix for Key Vault name (must be globally unique)
resource "random_string" "keyvault_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "${lower(replace(var.key_vault_name, "-", ""))}${random_string.keyvault_suffix.result}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Allow access from all networks for now (can be restricted later)
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "List",
    "Update",
    "Backup",
    "Restore",
    "Recover"
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Backup",
    "Restore",
    "Recover"
  ]

  certificate_permissions = [
    "Create",
    "Delete",
    "Get",
    "List",
    "Update",
    "Import",
    "Backup",
    "Restore",
    "Recover"
  ]
}

# Additional access policies for managed identities or users
resource "azurerm_key_vault_access_policy" "additional" {
  for_each = var.additional_access_policies

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = each.value.tenant_id
  object_id    = each.value.object_id

  key_permissions         = each.value.key_permissions
  secret_permissions      = each.value.secret_permissions
  certificate_permissions = each.value.certificate_permissions
}