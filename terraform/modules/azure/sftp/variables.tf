# EM SFTP Module Variables

# ==============================================================================
# Required Variables
# ==============================================================================

variable "rg_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "storage_account_name" {
  type        = string
  description = "SFTP storage account name (must be globally unique, 3-24 lowercase alphanumeric)"
}

# ==============================================================================
# Storage Account Configuration
# ==============================================================================

variable "create_sftp_storage" {
  type        = bool
  description = "Create SFTP storage account"
  default     = true
}

variable "account_kind" {
  type        = string
  description = "Storage account kind (StorageV2 or BlockBlobStorage)"
  default     = "BlockBlobStorage"

  validation {
    condition     = contains(["StorageV2", "BlockBlobStorage"], var.account_kind)
    error_message = "Account kind must be StorageV2 or BlockBlobStorage."
  }
}

variable "account_tier" {
  type        = string
  description = "Storage account tier (Standard or Premium)"
  default     = "Standard"
}

variable "replication_type" {
  type        = string
  description = "Storage replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  default     = "GRS"
}

variable "access_tier" {
  type        = string
  description = "Storage access tier (Hot or Cool)"
  default     = "Hot"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access (should be false for production)"
  default     = false
}

variable "network_default_action" {
  type        = string
  description = "Default network action (Allow or Deny)"
  default     = "Deny"
}

variable "allowed_subnet_ids" {
  type        = list(string)
  description = "Allowed subnet IDs for storage access"
  default     = []
}

variable "allowed_ip_addresses" {
  type        = list(string)
  description = "Allowed IP addresses for storage access (CIDR format)"
  default     = []
}

variable "enable_versioning" {
  type        = bool
  description = "Enable blob versioning"
  default     = true
}

variable "enable_change_feed" {
  type        = bool
  description = "Enable blob change feed"
  default     = true
}

variable "enable_managed_identity" {
  type        = bool
  description = "Enable System Assigned Managed Identity for storage account"
  default     = false
}

variable "blob_delete_retention_days" {
  type        = number
  description = "Days to retain deleted blobs"
  default     = 30
}

variable "container_delete_retention_days" {
  type        = number
  description = "Days to retain deleted containers"
  default     = 30
}

variable "containers" {
  type        = map(any)
  description = "Storage containers to create (e.g., incoming, outgoing, archive)"
  default = {
    incoming = {}
    outgoing = {}
    archive  = {}
  }
}

# ==============================================================================
# Monitoring and Logging
# ==============================================================================

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostics"
  default     = null
}

# ==============================================================================
# NAT Gateway Configuration
# ==============================================================================

variable "create_nat_gateway" {
  type        = bool
  description = "Create NAT Gateway for outbound connectivity"
  default     = true
}

variable "nat_gateway_name" {
  type        = string
  description = "NAT Gateway name"
  default     = ""
}

variable "nat_gateway_pip_name" {
  type        = string
  description = "NAT Gateway Public IP name"
  default     = ""
}

variable "nat_idle_timeout" {
  type        = number
  description = "NAT Gateway idle timeout in minutes (4-120)"
  default     = 10
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for NAT Gateway and Firewall"
  default     = ["1"]
}

# ==============================================================================
# Networking Configuration
# ==============================================================================

variable "sftp_subnet_id" {
  type        = string
  description = "SFTP subnet ID for private endpoint"
  default     = null
}

variable "subnet_name" {
  type        = string
  description = "SFTP subnet name (for NSG naming)"
  default     = "SFTP-SUBNET"
}

variable "vnet_id" {
  type        = string
  description = "Virtual Network ID for private DNS zone link"
  default     = null
}

variable "vnet_name" {
  type        = string
  description = "Virtual Network name for DNS zone link naming"
  default     = ""
}

# ==============================================================================
# Private Endpoint Configuration
# ==============================================================================

variable "create_private_endpoint" {
  type        = bool
  description = "Create private endpoint for storage account"
  default     = true
}

variable "private_endpoint_name" {
  type        = string
  description = "Private endpoint name"
  default     = ""
}

variable "create_private_dns_zone" {
  type        = bool
  description = "Create private DNS zone for blob storage"
  default     = true
}

# ==============================================================================
# Network Security Group Configuration
# ==============================================================================

variable "create_sftp_nsg" {
  type        = bool
  description = "Create dedicated NSG for SFTP subnet"
  default     = true
}

variable "sftp_allowed_source_ips" {
  type        = list(string)
  description = "Allowed source IP addresses for SFTP access (CIDR format)"
  default     = []
}

# ==============================================================================
# Azure Firewall Configuration
# ==============================================================================

variable "create_firewall" {
  type        = bool
  description = "Create Azure Firewall for SFTP traffic control"
  default     = false
}

variable "firewall_name" {
  type        = string
  description = "Azure Firewall name"
  default     = ""
}

variable "firewall_pip_name" {
  type        = string
  description = "Azure Firewall Public IP name"
  default     = ""
}

variable "firewall_sku_tier" {
  type        = string
  description = "Azure Firewall SKU tier (Standard or Premium)"
  default     = "Standard"
}

variable "firewall_subnet_id" {
  type        = string
  description = "AzureFirewallSubnet ID (must be named exactly 'AzureFirewallSubnet')"
  default     = null
}

variable "firewall_policy_id" {
  type        = string
  description = "Azure Firewall Policy ID (if using policy-based firewall)"
  default     = null
}

# ==============================================================================
# Automation Account Configuration
# ==============================================================================

variable "create_automation_account" {
  type        = bool
  description = "Create Azure Automation Account for SFTP data movement"
  default     = false
}

variable "automation_account_name" {
  type        = string
  description = "Automation Account name"
  default     = ""
}

variable "sftp_sync_runbook_content" {
  type        = string
  description = "Custom PowerShell runbook content for SFTP sync (leave empty for default)"
  default     = ""
}

variable "enable_automation_schedule" {
  type        = bool
  description = "Enable automation schedule for periodic sync"
  default     = false
}

variable "automation_schedule_frequency" {
  type        = string
  description = "Automation schedule frequency (Hour, Day, Week, Month)"
  default     = "Hour"
}

variable "automation_schedule_interval" {
  type        = number
  description = "Automation schedule interval"
  default     = 1
}

variable "automation_schedule_timezone" {
  type        = string
  description = "Automation schedule timezone"
  default     = "UTC"
}

variable "automation_source_container" {
  type        = string
  description = "Source container for automation sync"
  default     = "incoming"
}

variable "automation_destination_path" {
  type        = string
  description = "Destination path for automation sync (SMB share path)"
  default     = ""
}

variable "create_automation_private_endpoint" {
  type        = bool
  description = "Create private endpoint for Automation Account"
  default     = true
}

variable "create_automation_private_dns_zone" {
  type        = bool
  description = "Create private DNS zone for Automation Account"
  default     = true
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
