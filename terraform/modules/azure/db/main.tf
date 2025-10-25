# Oracle Database Module for Azure
# This module creates an Oracle Enterprise Linux VM with comprehensive storage layout
#
# RESTORE FROM SNAPSHOT FEATURE:
# This module supports two deployment modes:
# 1. NEW DEPLOYMENT: Creates a fresh Oracle Linux VM with empty data disks
# 2. RESTORE FROM SNAPSHOT: Creates a VM from existing snapshots (OS + data disks)
#
# Restore Use Cases:
# - Restore Oracle DB from production snapshots to a new environment
# - Clone existing Oracle database for testing/development
# - Disaster recovery scenarios
# - Cross-subscription database migrations
#
# Required variables for restore:
# - restore_from_snapshot = true
# - source_os_disk_snapshot_id = "/subscriptions/.../snapshots/os-disk-snapshot"
# - source_data_disk_snapshot_ids = [list of data disk snapshot IDs]
#
# Optional variables for cross-subscription restore:
# - snapshot_subscription_id = "source subscription ID"
# - snapshot_resource_group = "source resource group name"

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>1.0"
    }
  }
}

# Local variables
locals {
  prefix = "${var.location_code}-${var.client}-${var.environment}"

  # Validate restore configuration
  is_valid_restore_config = var.restore_from_snapshot ? (
    var.source_os_disk_snapshot_id != null || var.source_vm_restore_point_id != null
  ) : true
}


# Network Security Group Rules for Oracle Database (only created if create_nsg is true)
resource "azurerm_network_security_rule" "oracle_listener" {
  count                       = var.create_nsg ? 1 : 0
  name                        = "Allow-Oracle-Listener"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1521"
  source_address_prefix       = var.spoke_vnet_address_space
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.oracle_nsg[0].name
}

resource "azurerm_network_security_rule" "oracle_sqlnet" {
  count                       = var.create_nsg ? 1 : 0
  name                        = "Allow-Oracle-SQLNet"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1526"
  source_address_prefix       = var.spoke_vnet_address_space
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.oracle_nsg[0].name
}

resource "azurerm_network_security_rule" "oracle_enterprise_manager" {
  count                       = var.create_nsg ? 1 : 0
  name                        = "Allow-Oracle-EM"
  priority                    = 1020
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["1158", "5500"]
  source_address_prefix       = var.spoke_vnet_address_space
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.oracle_nsg[0].name
}

resource "azurerm_network_security_rule" "smb" {
  count                       = var.create_nsg ? 1 : 0
  name                        = "Allow-SMB"
  priority                    = 1040
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefix       = var.spoke_vnet_address_space
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.oracle_nsg[0].name
}

resource "azurerm_network_security_group" "oracle_nsg" {
  count               = var.create_nsg ? 1 : 0
  name                = "${local.prefix}-DB-NSG-${var.vm_name}"
  location            = var.location
  resource_group_name = var.rg_name

  tags = merge(var.tags, {
    Purpose = "Oracle Database Security"
    Module  = "db"
  })
}

# Local variable to determine which NSG ID to use
locals {
  nsg_id = var.create_nsg ? azurerm_network_security_group.oracle_nsg[0].id : var.network_security_group_id
}

# Network Interface for Oracle VM
resource "azurerm_network_interface" "oracle_nic" {
  name                = "${var.vm_name}-NIC"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(var.tags, {
    Purpose = "Oracle Database Network Interface"
    Module  = "db"
  })
}

# Associate NSG to NIC
resource "azurerm_network_interface_security_group_association" "oracle_nic_nsg" {
  network_interface_id      = azurerm_network_interface.oracle_nic.id
  network_security_group_id = local.nsg_id
}

# Local variables for restore logic
locals {
  # Full VM restore (OS + data disks from restore point)
  is_using_full_vm_restore = var.restore_from_snapshot && !var.restore_data_disks_only

  # Data-disk-only restore (fresh OS + restored data disks)
  is_using_data_disk_restore = var.restore_from_snapshot && var.restore_data_disks_only

  # For backward compatibility
  is_using_vm_restore_point = local.is_using_full_vm_restore
}

# Data source to get current Azure client config
data "azurerm_client_config" "current" {}

# Restore disks from disk restore points using azapi
# OS Disk from disk restore point
resource "azapi_resource" "os_disk_from_restore_point" {
  count     = local.is_using_vm_restore_point ? 1 : 0
  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "${var.vm_name}-OsDisk"
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.rg_name}"
  
  body = jsonencode({
    properties = {
      osType = "Linux"
      creationData = {
        createOption = "Restore"
        sourceResourceId = var.source_os_disk_snapshot_id
      }
    }
    sku = {
      name = var.os_disk_storage_type
    }
  })

  tags = merge(var.tags, {
    Purpose      = "Oracle Database OS Disk"
    Module       = "db"
    RestoredFrom = "DiskRestorePoint"
  })

  schema_validation_enabled = false
}

# Data Disks from disk restore points (for both full restore and data-disk-only restore)
resource "azapi_resource" "data_disks_from_restore_point" {
  count     = var.restore_from_snapshot ? length(var.source_data_disk_snapshot_ids) : 0
  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "${var.vm_name}-DataDisk-${count.index + 1}"
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.rg_name}"
  
  body = jsonencode({
    properties = {
      creationData = {
        createOption     = "Restore"
        sourceResourceId = var.source_data_disk_snapshot_ids[count.index]
      }
    }
    sku = {
      name = var.disk_storage_type
    }
  })

  tags = merge(var.tags, {
    Purpose      = "Oracle Database Storage"
    Module       = "db"
    DiskPurpose  = "DataDisk-${count.index + 1}"
    RestoredFrom = "DiskRestorePoint"
  })

  schema_validation_enabled = false
}

# Create VM with restored disks using azapi (supports TrustedLaunch with attached disks)
resource "azapi_resource" "vm_from_restore_point" {
  count     = local.is_using_vm_restore_point ? 1 : 0
  type      = "Microsoft.Compute/virtualMachines@2025-04-01"
  name      = var.vm_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.rg_name}"

  body = jsonencode({
    properties = {
      hardwareProfile = {
        vmSize = var.vm_size
      }
      storageProfile = {
        osDisk = {
          name         = azapi_resource.os_disk_from_restore_point[0].name
          managedDisk = {
            id = azapi_resource.os_disk_from_restore_point[0].id
          }
          caching      = "ReadWrite"
          createOption = "Attach"
          osType       = "Linux"
        }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azurerm_network_interface.oracle_nic.id
            properties = {
              primary = true
            }
          }
        ]
      }
      securityProfile = {
        securityType = "TrustedLaunch"
        uefiSettings = {
          secureBootEnabled = true
          vTpmEnabled       = true
        }
      }
    }
    identity = {
      type = "SystemAssigned"
    }
  })

  tags = merge(var.tags, {
    Purpose      = "Oracle Database Server"
    Module       = "db"
    OS           = "Oracle Linux"
    RestoredFrom = "VMRestorePoint"
  })

  depends_on = [
    azapi_resource.os_disk_from_restore_point,
    azapi_resource.data_disks_from_restore_point
  ]

  schema_validation_enabled = false
}

# For non-restore scenarios, keep existing implementation
# (OS and data disks with vanilla VM creation)
# Data Disks for vanilla deployment (only when NOT restoring at all)
resource "azurerm_managed_disk" "oracle_data_disks" {
  count                = !var.restore_from_snapshot ? length(local.data_disks) : 0
  name                 = "${var.vm_name}-DataDisk-${count.index + 1}"
  location             = var.location
  resource_group_name  = var.rg_name
  storage_account_type = var.disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = local.data_disks[count.index].size_gb

  tags = merge(var.tags, {
    Purpose      = "Oracle Database Storage"
    Module       = "db"
    DiskPurpose  = "DataDisk-${count.index + 1}"
    MountPath    = local.data_disks[count.index].mount_path
    RestoredFrom = "New"
  })
}

# Oracle Linux Virtual Machine (vanilla deployment OR data-disk-only restore)
# Uses fresh OS for both scenarios
resource "azurerm_linux_virtual_machine" "vm_new" {
  count               = !local.is_using_full_vm_restore ? 1 : 0
  name                = var.vm_name
  location            = var.location
  resource_group_name = var.rg_name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.disable_password_authentication ? null : var.admin_password

  # Disable password authentication (use SSH keys only for Linux)
  disable_password_authentication = var.disable_password_authentication

  network_interface_ids = [
    azurerm_network_interface.oracle_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Oracle"
    offer     = "Oracle-Linux"
    sku       = var.oracle_linux_version
    version   = "latest"
  }

  # Security configuration for trusted launch
  secure_boot_enabled = true
  vtpm_enabled        = true

  # SSH Key configuration for Linux
  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Cloud-init configuration for Oracle preparation
  custom_data = var.enable_oracle_prep ? base64encode(templatefile("${path.module}/scripts/cloud-init.yml", {
    oracle_data_dir         = var.oracle_data_dir
    oracle_base             = var.oracle_base
    oracle_home             = var.oracle_home
    admin_username          = var.admin_username
    restore_data_disks_only = var.restore_data_disks_only
    restore_from_snapshot   = var.restore_from_snapshot
  })) : null

  tags = merge(var.tags, {
    Purpose = "Oracle Database Server"
    Module  = "db"
    OS      = "Oracle Linux"
  })

}

# Local variable to determine which VM ID to use
locals {
  vm_id = local.is_using_vm_restore_point ? azapi_resource.vm_from_restore_point[0].id : azurerm_linux_virtual_machine.vm_new[0].id
}

# Attach data disks to VM from restore point (full VM restore only)
resource "azurerm_virtual_machine_data_disk_attachment" "oracle_data_disk_attachment_restore" {
  count              = local.is_using_full_vm_restore ? length(local.data_disks) : 0
  managed_disk_id    = azapi_resource.data_disks_from_restore_point[count.index].id
  virtual_machine_id = local.vm_id
  lun                = local.data_disks[count.index].lun
  caching            = "ReadWrite"
}

# Attach data disks to VM (vanilla deployment - fresh empty disks)
resource "azurerm_virtual_machine_data_disk_attachment" "oracle_data_disk_attachment" {
  count              = !var.restore_from_snapshot ? length(local.data_disks) : 0
  managed_disk_id    = azurerm_managed_disk.oracle_data_disks[count.index].id
  virtual_machine_id = local.vm_id
  lun                = local.data_disks[count.index].lun
  caching            = "ReadWrite"
}

# Attach restored data disks to vanilla VM (data-disk-only restore mode)
resource "azurerm_virtual_machine_data_disk_attachment" "oracle_data_disk_attachment_data_only_restore" {
  count              = local.is_using_data_disk_restore ? length(local.data_disks) : 0
  managed_disk_id    = azapi_resource.data_disks_from_restore_point[count.index].id
  virtual_machine_id = local.vm_id
  lun                = local.data_disks[count.index].lun
  caching            = "ReadWrite"
}

# Key Vault Secret for database connection
resource "azurerm_key_vault_secret" "db_admin_password" {
  name         = "${var.vm_name}-admin-password"
  value        = var.admin_password
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Purpose = "Oracle Database Admin Password"
    Module  = "db"
  })
}

# Database connection string secret
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "${var.vm_name}-connection-string"
  value        = "Data Source=${azurerm_network_interface.oracle_nic.private_ip_address}:1521/${var.oracle_pdb};User Id=system;Password=${var.admin_password};"
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Purpose = "Oracle Database Connection String"
    Module  = "db"
  })
}

# Local reference to data disks configuration
locals {
  data_disks = var.data_disks
}