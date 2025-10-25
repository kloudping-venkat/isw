# Oracle Database Module Variables

# Basic Configuration
variable "vm_name" {
  description = "Name of the Oracle database VM"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "rg_name" {
  description = "Resource group name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the VM will be placed"
  type        = string
}

# VM Configuration
variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_E4s_v3"
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "oracle"
}

variable "admin_password" {
  description = "Administrator password for the VM (stored in Key Vault)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VM authentication"
  type        = string
  default     = null
}

variable "disable_password_authentication" {
  description = "Disable password authentication for SSH (Linux only)"
  type        = bool
  default     = false
}

# Storage Configuration
variable "os_disk_storage_type" {
  description = "Storage type for OS disk"
  type        = string
  default     = "Premium_LRS"
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 256
}

variable "disk_storage_type" {
  description = "Storage type for data disks"
  type        = string
  default     = "Premium_LRS"
}

# Oracle Configuration
variable "oracle_sid" {
  description = "Oracle Database SID (System Identifier)"
  type        = string
  default     = "ORCL"
}

variable "oracle_pdb" {
  description = "Oracle Pluggable Database name"
  type        = string
  default     = "ORCLPDB"
}

variable "oracle_linux_version" {
  description = "Oracle Linux version"
  type        = string
  default     = "8-4"
}

variable "enable_oracle_prep" {
  description = "Enable Oracle preparation via cloud-init during VM boot"
  type        = bool
  default     = false
}

variable "oracle_base" {
  description = "Oracle Base Directory"
  type        = string
  default     = "/u01/home/app/oracle"
}

variable "oracle_home" {
  description = "Oracle Home Directory"
  type        = string
  default     = "/u01/home/app/oracle/product/19.0.0/dbhome_1"
}

variable "oracle_data_dir" {
  description = "Oracle Data Directory"
  type        = string
  default     = "/u01/app/oracle/oradata"
}

# Network Configuration
variable "spoke_vnet_address_space" {
  description = "Address space of the spoke VNet for security rules"
  type        = string
}

variable "network_security_group_id" {
  description = "ID of existing Network Security Group to use (if not provided, a new one will be created)"
  type        = string
  default     = null
}

variable "create_nsg" {
  description = "Whether to create a new Network Security Group (set to false if using existing NSG)"
  type        = bool
  default     = true
}

# Key Vault Configuration
variable "key_vault_id" {
  description = "Key Vault ID for storing database credentials"
  type        = string
  default     = null
}

variable "create_key_vault_secrets" {
  description = "Whether to create key vault secrets for database credentials"
  type        = bool
  default     = false
}

# Environment Configuration
variable "location_code" {
  description = "Location code for resource naming"
  type        = string
}

variable "client" {
  description = "Client name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
}

# Data Disks Configuration
# Default: 3 data disks for CS environment
# /u01 (512GB) - Oracle base directory (includes software and data)
# /u02 (512GB) - Oracle data files
# /u03 (512GB) - Oracle data files
# Additional disks (/u04, /u05, /archlog) are optional for production
variable "data_disks" {
  description = "Configuration for database data disks (mount points will be created by cloud-init)"
  type = list(object({
    size_gb    = number
    mount_path = string
    lun        = number
  }))
  default = [
    { size_gb = 512, mount_path = "/u01", lun = 0 }, # Oracle base directory
    { size_gb = 512, mount_path = "/u02", lun = 1 }, # Oracle data files
    { size_gb = 512, mount_path = "/u03", lun = 2 }  # Oracle data files
  ]
}

# Restore from Snapshot Configuration
variable "restore_from_snapshot" {
  description = "Enable creating VM from an existing snapshot or restore point"
  type        = bool
  default     = false
}

variable "restore_data_disks_only" {
  description = "When true, only restore data disks (not OS disk) - creates fresh OS with restored data. When false, restores full VM including OS disk."
  type        = bool
  default     = false
}

variable "source_vm_id" {
  description = "Resource ID of the source VM to restore from (required if restore_from_snapshot is true)"
  type        = string
  default     = null
}

variable "source_vm_restore_point_id" {
  description = "Resource ID of the restore point to use for restoration (optional - if not provided, will use latest snapshot)"
  type        = string
  default     = null
}

variable "source_os_disk_snapshot_id" {
  description = "Resource ID of the OS disk snapshot to restore from (alternative to restore point)"
  type        = string
  default     = null
}

variable "source_data_disk_snapshot_ids" {
  description = "List of resource IDs for data disk snapshots to restore (must match data_disks count and order)"
  type        = list(string)
  default     = []
}

variable "snapshot_subscription_id" {
  description = "Subscription ID where the source snapshots exist (for cross-subscription restore)"
  type        = string
  default     = null
}

variable "snapshot_resource_group" {
  description = "Resource group name where the source snapshots exist (for cross-subscription restore)"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}