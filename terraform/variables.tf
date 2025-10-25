variable "location_code" {
  description = "Location code (e.g., US1)"
  type        = string
  default     = "US1"
}

variable "client" {
  description = "Client name (e.g., BOFA, EM)"
  type        = string
  default     = "BOFA"
}

variable "environment" {
  description = "Environment/Instance identifier (e.g., CS, P, D, T, S, WM)"
  type        = string
  default     = "CS"

  validation {
    condition     = can(regex("^[A-Z0-9]{1,10}$", var.environment))
    error_message = "Environment must be 1-10 uppercase alphanumeric characters (e.g., P, CS, WM, PROD, DEV)."
  }
}

variable "environment_code" {
  description = "Short code for Windows computer names (max 4 chars for 15 char limit). Defaults to environment if not set."
  type        = string
  default     = ""
}

# Resource Group Configuration
variable "resource_groups" {
  description = "List of resource groups to create following production pattern"
  type        = list(string)
  default     = ["HUB", "SPOKE", "WEB", "APP", "DB", "ADO", "SFTP", "SMTP", "HSM", "DS", "LOGI"]
}

# Logi AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.33"
}

variable "enable_logi_dedicated_nodes" {
  description = "Enable dedicated node pool for Logi Symphony workloads"
  type        = bool
  default     = true
}

variable "logi_node_taints" {
  description = "Node taints for Logi Symphony dedicated nodes"
  type        = list(string)
  default     = ["workload=analytics:NoSchedule"]
}

# SFTP Configuration
variable "enable_sftp" {
  description = "Enable SFTP infrastructure (storage account, NAT gateway, private endpoint)"
  type        = bool
  default     = true
}

variable "enable_sftp_firewall" {
  description = "Enable Azure Firewall for SFTP (adds ~$500/month cost)"
  type        = bool
  default     = false
}

variable "enable_sftp_automation" {
  description = "Enable Automation Account for SFTP file sync to SMB shares"
  type        = bool
  default     = true
}

variable "aks_admin_group_object_ids" {
  description = "Azure AD group object IDs for AKS administrators"
  type        = list(string)
  default     = []
}

variable "aks_disable_local_accounts" {
  description = "Disable local accounts and use Azure AD only"
  type        = bool
  default     = true
}

variable "aks_private_cluster_enabled" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = false
}

variable "aks_private_cluster_public_fqdn_enabled" {
  description = "Enable public FQDN for private AKS cluster"
  type        = bool
  default     = false
}

variable "enable_aks_log_analytics" {
  description = "Enable Log Analytics workspace for AKS"
  type        = bool
  default     = true
}

variable "enable_aks_microsoft_defender" {
  description = "Enable Microsoft Defender for Containers"
  type        = bool
  default     = true
}

variable "enable_aks_azure_policy" {
  description = "Enable Azure Policy add-on for AKS"
  type        = bool
  default     = true
}

# External Container Registry Configuration
variable "external_logi_container_registry" {
  description = "Configuration for connecting to existing Logi Symphony container registry"
  type = object({
    name           = string
    resource_group = string
  })
  default = null
}

variable "logi_namespace_name" {
  description = "Kubernetes namespace name for Logi Symphony"
  type        = string
  default     = "logi-symphony"
}

variable "location" {
  description = "The Azure region where resources should be created"
  type        = string
}

# HUB Network variables
variable "hub_vnet_address_space" {
  description = "CIDR block for the HUB VNet"
  type        = string
  default     = "10.223.30.0/24"
}


# SPOKE Network variables
variable "spoke_vnet_address_space" {
  description = "CIDR block for the SPOKE VNet"
  type        = string
  default     = "10.223.48.0/21"
}

variable "spoke_subnets" {
  description = "Spoke VNet subnets configuration"
  type = map(object({
    address_prefix    = string
    service_endpoints = list(string)
  }))
  default = {
    "WEB-SUBNET" = {
      address_prefix    = "10.223.48.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Web"]
    }
    "APP-SUBNET" = {
      address_prefix    = "10.223.49.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
    }
    "DB-SUBNET" = {
      address_prefix    = "10.223.50.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
    }
    "ADO-SUBNET" = {
      address_prefix    = "10.223.51.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    }
    "LOGI-SUBNET" = {
      address_prefix    = "10.223.52.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    }
    "AG-SUBNET" = {
      address_prefix    = "10.223.53.0/24"
      service_endpoints = []
    }
    "SFTP-SUBNET" = {
      address_prefix    = "10.223.54.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }
  }
}

# Azure AD Configuration for VPN Gateway
# Tenant ID is automatically retrieved from current Azure authentication context

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Azure DevOps Configuration
variable "ado_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/your-org)"
  type        = string
  default     = "https://dev.azure.com/insight-certent" # Updated to match actual organization
}

variable "ado_deployment_pool" {
  description = "Azure DevOps deployment pool name"
  type        = string
  default     = "EM-BOFA-PROD"
}

variable "ado_pat_token" {
  description = "Azure DevOps Personal Access Token (passed from Azure DevOps pipeline variables)"
  type        = string
  sensitive   = true
  default     = ""
}

# Azure AD Domain Services VNet Configuration
variable "aadds_vnet_name" {
  description = "Name of the Azure AD Domain Services VNet"
  type        = string
  default     = "US1-BOFA-P-DS-VNET"
}

variable "aadds_vnet_resource_group" {
  description = "Resource group containing the Azure AD Domain Services VNet"
  type        = string
  default     = "US1-BOFA-P-DS"
}

variable "aadds_vnet_id" {
  description = "Full resource ID of the Azure AD Domain Services VNet for peering"
  type        = string
  default     = null # Will be constructed if not provided
}

# Removed nva_ip_address variable - no longer needed since NVA route was removed

variable "aadds_address_prefix" {
  description = "CIDR block for the Azure AD Domain Services subnet"
  type        = string
  default     = "10.223.26.0/24"
}

# SSH Configuration
variable "ssh_public_key" {
  description = "SSH public key for Linux VMs"
  type        = string
  default     = null
}

# Oracle Database Configuration
variable "oracle_sid" {
  description = "Oracle database system identifier (SID)"
  type        = string
  default     = "ORCL"
}

variable "oracle_pdb" {
  description = "Oracle pluggable database name"
  type        = string
  default     = "ORCLPDB"
}

# VM Extensions Configuration
variable "enable_vm_extensions" {
  description = "Whether to enable VM extensions for configuration"
  type        = bool
  default     = true
}

# DNS Configuration
variable "dns_servers" {
  description = "List of DNS servers for VNet configuration"
  type        = list(string)
  default     = []
}

# Module Enable/Disable Flags
variable "enable_hub" {
  description = "Create hub VNet and VPN gateway (disable for Walmart - uses shared hub)"
  type        = bool
  default     = true
}

variable "enable_web_vms" {
  description = "Enable Web tier VMs"
  type        = bool
  default     = false
}

variable "enable_app_vms" {
  description = "Enable App tier VMs"
  type        = bool
  default     = false
}

variable "enable_db_vms" {
  description = "Enable Database tier VMs"
  type        = bool
  default     = false
}

# ========================================
# DATABASE VM CONFIGURATION
# ========================================
variable "enable_db_vm_01" {
  description = "Enable Database VM01 (disabled by default, can be enabled in specific environments like Walmart)"
  type        = bool
  default     = false
}

variable "enable_db_vm_02" {
  description = "Enable Database VM02 (primary DB VM)"
  type        = bool
  default     = true
}

# ========================================
# DATABASE VM SNAPSHOT RESTORE CONFIGURATION
# ========================================
# Use these variables to restore a DB VM from an existing snapshot
# instead of creating a new vanilla VM

variable "db_vm_size" {
  description = "VM size for database server (overrides default if specified)"
  type        = string
  default     = null
}

variable "db_restore_from_snapshot" {
  description = "Enable restoring DB VM from an existing snapshot or restore point"
  type        = bool
  default     = false
}

variable "db_restore_data_disks_only" {
  description = "When true, only restore data disks (fresh OS + restored data). When false, restore full VM (OS + data)."
  type        = bool
  default     = false
}

variable "db_source_vm_id" {
  description = "Resource ID of the source VM to restore from (optional reference)"
  type        = string
  default     = null
}

variable "db_source_vm_restore_point_id" {
  description = "Resource ID of the restore point to use for DB restoration"
  type        = string
  default     = null
}

variable "db_source_os_disk_snapshot_id" {
  description = "Resource ID of the OS disk snapshot to restore DB VM from (required if restore_from_snapshot is true)"
  type        = string
  default     = null
}

variable "db_source_data_disk_snapshot_ids" {
  description = "List of resource IDs for data disk snapshots to restore (must match data_disks count)"
  type        = list(string)
  default     = []
}

variable "db_snapshot_subscription_id" {
  description = "Subscription ID where the source DB snapshots exist (for cross-subscription restore)"
  type        = string
  default     = null
}

variable "db_snapshot_resource_group" {
  description = "Resource group name where the source DB snapshots exist"
  type        = string
  default     = null
}

variable "db_enable_oracle_prep" {
  description = "Enable cloud-init oracle preparation for DB VM01"
  type        = bool
  default     = true
}

# ========================================
# DATABASE VM02 SNAPSHOT RESTORE CONFIGURATION
# ========================================
# Use these variables to restore the second DB VM from an existing snapshot
# Follows the same pattern as DB-VM01 but with _02 suffix

variable "db_vm_02_restore_from_snapshot" {
  description = "Enable restoring DB VM02 from an existing snapshot or restore point"
  type        = bool
  default     = false
}

variable "db_vm_02_restore_data_disks_only" {
  description = "When true, only restore data disks for VM02 (fresh OS + restored data). When false, restore full VM (OS + data)."
  type        = bool
  default     = false
}

variable "db_vm_02_source_os_disk_snapshot_id" {
  description = "Resource ID of the OS disk snapshot to restore DB VM02 from (required if restore_from_snapshot is true and restore_data_disks_only is false)"
  type        = string
  default     = null
}

variable "db_vm_02_source_vm_restore_point_id" {
  description = "Resource ID of the restore point to use for DB VM02 restoration"
  type        = string
  default     = null
}

variable "db_vm_02_source_data_disk_snapshot_ids" {
  description = "List of resource IDs for data disk snapshots to restore for DB VM02 (must match data_disks count)"
  type        = list(string)
  default     = []
}

variable "db_vm_02_snapshot_subscription_id" {
  description = "Subscription ID where the source DB snapshots exist for VM02 (for cross-subscription restore)"
  type        = string
  default     = null
}

variable "db_vm_02_snapshot_resource_group" {
  description = "Resource group name where the source DB snapshots exist for VM02"
  type        = string
  default     = null
}

variable "db_vm_02_enable_oracle_prep" {
  description = "Enable cloud-init oracle preparation for DB VM02"
  type        = bool
  default     = true
}

variable "enable_ado_vms" {
  description = "Enable Azure DevOps agent VMs"
  type        = bool
  default     = false
}

# App Server gMSA Configuration
variable "app_service_account" {
  description = "gMSA service account for APP servers (e.g., svc_appsrv_wm$ for Walmart)"
  type        = string
  default     = null # null means don't configure gMSA for APP servers
}

variable "enable_aks" {
  description = "Enable AKS cluster (Logi)"
  type        = bool
  default     = false
}

# Shared Hub Configuration (for Walmart)
variable "use_shared_hub" {
  description = "Use existing hub VNet instead of creating new one (for Walmart environment)"
  type        = bool
  default     = false
}

variable "shared_hub_vnet_name" {
  description = "Name of the existing hub VNet to use (for Walmart)"
  type        = string
  default     = ""
}

variable "shared_hub_vnet_resource_group" {
  description = "Resource group of the existing hub VNet (for Walmart)"
  type        = string
  default     = ""
}

variable "shared_hub_vnet_id" {
  description = "Full resource ID of the existing hub VNet for peering (for Walmart)"
  type        = string
  default     = ""
}

# Application Gateway Health Probes Configuration
variable "appgw_probes_list" {
  description = "Map of health probe configurations for Application Gateway"
  type = map(object({
    protocol            = string
    host                = string
    path                = string
    interval            = optional(number, 30)
    timeout             = optional(number, 30)
    unhealthy_threshold = optional(number, 3)
    match_status_codes  = optional(list(string), ["200-399"])
  }))
  default = {}
}

# Application Gateway Backend HTTP Settings Configuration
variable "appgw_backend_http_settings_list" {
  description = "Map of backend HTTP settings configurations for Application Gateway"
  type = map(object({
    port                  = number
    protocol              = string
    cookie_based_affinity = string
    request_timeout       = optional(number, 300)
    probe_name            = string
  }))
  default = {}
}

# Application Gateway HTTP Listeners Configuration
variable "appgw_http_listeners_list" {
  description = "Map of HTTP listener configurations for Application Gateway"
  type = map(object({
    protocol             = string
    frontend_port_name   = optional(string, "httpsPort")
    ssl_certificate_name = optional(string)
    require_sni          = optional(bool, false)
    host_names           = optional(list(string), [])
    host_name            = optional(string)
  }))
  default = {}
}

# Application Gateway Request Routing Rules Configuration
variable "appgw_request_routing_rules_list" {
  description = "Map of request routing rule configurations for Application Gateway"
  type = map(object({
    rule_type                  = optional(string, "Basic")
    http_listener_name         = string
    backend_address_pool_name  = string
    backend_http_settings_name = string
    priority                   = number
  }))
  default = {}
}
