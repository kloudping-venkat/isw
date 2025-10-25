# Walmart Environment Configuration for EM NextGen Infrastructure
# PHASE 2: Full Infrastructure - Networking + VMs + SFTP
# Spoke network peers to shared CS hub

# Basic Environment Configuration
location_code = "US1"
client        = "BOFA" # Same client as CS for consistent naming
environment   = "WM"   # WM = Walmart (differentiates from CS)
environment_code = "WM" # Short code for computer names
location      = "East US"

# ========================================
# MODULE ENABLE/DISABLE FLAGS
# ========================================
enable_hub             = false # Use shared CS hub
enable_sftp            = true  # Enable SFTP
enable_sftp_automation = false # Disable to avoid Automation Account quota
enable_web_vms         = true  # Enable Web VMs
enable_app_vms         = true  # Enable App VMs
enable_db_vms          = true  # Enable DB VMs
enable_ado_vms         = true  # Enable ADO agent VMs
enable_aks             = false # AKS not needed yet

# Shared Hub Configuration
use_shared_hub                 = true
shared_hub_vnet_name           = "US1-BOFA-CS-HUB-VNET"
shared_hub_vnet_resource_group = "US1-BOFA-CS-HUB"
shared_hub_vnet_id             = "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-HUB/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-HUB-VNET"

# Spoke Network Configuration - UNIQUE CIDR for Walmart
# Using 10.225.0.0/21 for Walmart workloads (NO CONFLICTS)
# Total range: 10.225.0.0 - 10.225.7.255 (2048 IPs, supports 8 /24 subnets)
#
# CIDR Allocation Summary:
# - CS:     10.223.40.0/24 (hub) + 10.223.48.0/21 (spoke)
# - BAML:   10.224.x.x ranges
# - Walmart: 10.225.0.0/21 (spoke only - no hub needed)
#
# Walmart Spoke Subnets (all /24 for 256 IPs each):
# - Web Subnet: 10.225.0.0/24 (256 IPs)
# - App Subnet: 10.225.1.0/24 (256 IPs)
# - Database Subnet: 10.225.2.0/24 (256 IPs)
# - DevOps Subnet: 10.225.3.0/24 (256 IPs)
# - Logi Subnet: 10.225.4.0/24 (256 IPs) - AKS will use this subnet
# - Application Gateway Subnet: 10.225.5.0/24 (256 IPs) - Dedicated for App Gateway
# - SFTP Subnet: 10.225.6.0/24 (256 IPs)
# - Available: 10.225.7.0/24 (future expansion)
spoke_vnet_address_space = "10.225.0.0/21"

spoke_subnets = {
  "WEB-SUBNET" = {
    address_prefix    = "10.225.0.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Web"]
  }
  "APP-SUBNET" = {
    address_prefix    = "10.225.1.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  "DB-SUBNET" = {
    address_prefix    = "10.225.2.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  "ADO-SUBNET" = {
    address_prefix    = "10.225.3.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
  }
  "LOGI-SUBNET" = {
    address_prefix    = "10.225.4.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
  }
  "AG-SUBNET" = {
    address_prefix    = "10.225.5.0/24"
    service_endpoints = ["Microsoft.KeyVault"]
  }
  "SFTP-SUBNET" = {
    address_prefix    = "10.225.6.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }
}

# DNS Configuration - Use Domain Controllers for domain join
# These are the Azure AD Domain Services IPs (same as CS environment)
dns_servers = ["10.223.26.68", "10.223.26.69", "8.8.8.8"]

# Azure DevOps Configuration
ado_organization_url = "https://dev.azure.com/insight-certent/"
ado_deployment_pool  = "EM-WALMART-PROD"

# App Server gMSA Configuration
# This gMSA account will be installed on APP servers for running application services
app_service_account = "svc_appsrv_wm$"

# Azure AD Domain Services VNet Configuration (for domain join)
# VMs will be domain-joined to the same domain as CS
aadds_vnet_name           = "US1-BOFA-P-DS-VNET"
aadds_vnet_resource_group = "US1-BOFA-P-DS"
aadds_address_prefix      = "10.223.26.0/24"

# ========================================
# DATABASE VM CONFIGURATION
# ========================================
# Walmart uses dual DB instances for HA/load distribution
# DB-VM01: Primary instance (restored from CS DB-VM02)
# DB-VM02: Secondary instance (also restored from CS DB-VM02)
enable_db_vm_01 = false
enable_db_vm_02 = true

# ========================================
# DATABASE VM RESTORE - DATA DISKS ONLY
# ========================================
# Restore Strategy: Keep existing 256GB OS + Replace Data Disks
# - OS Disk: Keep existing 256GB disk (already expanded) - NO CHANGES
# - Data Disks: Restored from CS Production with correct data
#
# Source: CS Production VM Restore Point "OEL_9_5_install_19_21_data_loaded_v3"
# Created: 2025-10-13T09:55:50.2365392+00:00 (Updated restore point with latest data)
# Source VM: US1-BOFA-CS-DB-VM02
# Target VM: US1-BOFA-WM-DB-VM01
# VM Size: Standard_E4ds_v4
# Disks: 3 data disks (512GB each) with Oracle 19.21 + database + loaded data

db_restore_from_snapshot    = true
db_restore_data_disks_only  = true  # Only restore data disks, keep existing 256GB OS disk
db_enable_oracle_prep       = true  # Enable cloud-init to mount restored disks

# Restore Point Collection and Subscription Info
db_source_vm_restore_point_id = "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3"
db_snapshot_subscription_id   = "8590c10d-ae02-49ca-a8bb-435f047c71e9"
db_snapshot_resource_group    = "US1-BOFA-CS-DB"

# Data Disk Restore Points (in LUN order: 0, 1, 2)
# These contain Oracle binaries (/u01), data files (/u02), and backups (/u03)
db_source_data_disk_snapshot_ids = [
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02-DataDisk-1_c980f408-c682-41ad-a84c-0fde8cee8136",
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02-DataDisk-2_972a465c-052e-46e9-8f4c-4ce04c6c98cb",
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02-DataDisk-3_20c503cf-81ec-4c15-bf99-08af0a868a79"
]

# Note: OS disk will NOT be touched - keeping existing 256GB disk
# Only data disks will be replaced with correct restore point data

# ========================================
# DATABASE VM02 RESTORE - FULL VM RESTORE
# ========================================
# DB-VM02 Configuration: Complete VM restore (OS + All Disks)
# This creates a second Walmart DB instance (US1-BOFA-WM-DB-VM02)
# Restored entirely from the same CS production restore point as DB-VM01
#
# Restore Strategy: Complete VM Restore (including OS disk)
# - OS Disk: Restored from snapshot (256GB)
# - Data Disks: Restored from restore points (3x 512GB each)
# - All disks and OS configuration preserved from CS template
#
# Source: CS Production VM Restore Point "OEL_9_5_install_19_21_data_loaded_v3"
# Created: 2025-10-13T09:55:50.2365392+00:00
# Source VM: US1-BOFA-CS-DB-VM02
# Target VM: US1-BOFA-WM-DB-VM02
# VM Size: Standard_E4ds_v4
# Disks: 1 OS disk (256GB) + 3 data disks (512GB each) - fully restored
#
# Purpose: Secondary database instance for load distribution/HA
# Note: Both DB-VM01 and DB-VM02 will have identical Oracle database
#       Post-restore script will update hostname and Oracle configs
#       They can be configured as Oracle RAC nodes or Data Guard standbys

db_vm_02_restore_from_snapshot    = true
db_vm_02_restore_data_disks_only  = false  # Full VM restore (OS + data)
db_vm_02_enable_oracle_prep       = true   # Still need prep to update hostname and Oracle configs

# Restore Point Collection and Subscription Info (same as DB-VM01)
db_vm_02_source_vm_restore_point_id = "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3"
db_vm_02_snapshot_subscription_id   = "8590c10d-ae02-49ca-a8bb-435f047c71e9"
db_vm_02_snapshot_resource_group    = "US1-BOFA-CS-DB"

# OS Disk Restore Point
# Restored OS disk will preserve Oracle Linux configuration, kernel, and basic OS setup
# Using the SAME restore point as the data disks from OEL_9_5_install_19_21_data_loaded_v3
db_vm_02_source_os_disk_snapshot_id = "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02_OsDisk_1_926bcab3199044d48410a94913c5a0f8_04e59e46-c8de-4e83-afe0-75e3e9b95059"

# Data Disk Restore Points (in LUN order: 0, 1, 2)
# Using same restore point disks as DB-VM01 for consistency
db_vm_02_source_data_disk_snapshot_ids = [
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02-DataDisk-1_c980f408-c682-41ad-a84c-0fde8cee8136",
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02-DataDisk-2_972a465c-052e-46e9-8f4c-4ce04c6c98cb",
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/restorePointCollections/OEL_9_5_install_19_21/restorePoints/OEL_9_5_install_19_21_data_loaded_v3/diskRestorePoints/US1-BOFA-CS-DB-VM02-DataDisk-3_20c503cf-81ec-4c15-bf99-08af0a868a79"
]

# ========================================
# APPLICATION GATEWAY CONFIGURATION
# ========================================
# Health Probes - One for each backend domain
# These probe the Walmart environment backends
appgw_probes_list = {
  "US1-BOFA-WM-APPGWHP01" = {
    protocol            = "Https"
    host                = "emcsbofa.certent.com"
    path                = "/EM/Account/Login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }
  "US1-BOFA-WM-APPGWHP02" = {
    protocol            = "Https"
    host                = "emdcbofa.certent.com"
    path                = "/EM/Account/Login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }
}

# Backend HTTP Settings - One for each backend pool
appgw_backend_http_settings_list = {
  "US1-BOFA-WM-APPGWBACKPOOLSETTINGS01" = {
    port                  = 443
    protocol              = "Https"
    cookie_based_affinity = "Enabled"
    request_timeout       = 300
    probe_name            = "US1-BOFA-WM-APPGWHP01"
  }
  "US1-BOFA-WM-APPGWBACKPOOLSETTINGS02" = {
    port                  = 443
    protocol              = "Https"
    cookie_based_affinity = "Enabled"
    request_timeout       = 300
    probe_name            = "US1-BOFA-WM-APPGWHP02"
  }
}

# HTTP Listeners - One for each domain/service
# NOTE: These serve the Walmart environment, so using WM prefix
appgw_http_listeners_list = {
  # Walmart primary listener (CS domain routing through Walmart App Gateway)
  "US1-BOFA-WM-APPGWFRONTLISTENER01" = {
    protocol             = "Https"
    frontend_port_name   = "httpsPort"
    ssl_certificate_name = "starcertentcom2025"
    require_sni          = true
    host_names = [
      "emcsbofa.certent.com"
    ]
  }
  # Walmart secondary listener (Data Center domain)
  "US1-BOFA-WM-APPGWFRONTLISTENER02" = {
    protocol             = "Https"
    frontend_port_name   = "httpsPort"
    ssl_certificate_name = "starcertentcom2025"
    require_sni          = true
    host_names = [
      "emdcbofa.certent.com"
    ]
  }
}

# Request Routing Rules - Maps listeners to backend settings
# All rules deployed to Walmart environment using WM naming
appgw_request_routing_rules_list = {
  # Route CS domain through Walmart App Gateway to backend
  "US1-BOFA-WM-APPGWROUTINGRULE01" = {
    rule_type                  = "Basic"
    http_listener_name         = "US1-BOFA-WM-APPGWFRONTLISTENER01"
    backend_address_pool_name  = "backendPool"
    backend_http_settings_name = "US1-BOFA-WM-APPGWBACKPOOLSETTINGS01"
    priority                   = 100
  }
  # Route DC domain through Walmart App Gateway to backend
  "US1-BOFA-WM-APPGWROUTINGRULE02" = {
    rule_type                  = "Basic"
    http_listener_name         = "US1-BOFA-WM-APPGWFRONTLISTENER02"
    backend_address_pool_name  = "backendPool"
    backend_http_settings_name = "US1-BOFA-WM-APPGWBACKPOOLSETTINGS02"
    priority                   = 101
  }
}

# Resource Tags
tags = {
  Environment   = "WALMART"
  Client        = "BOFA" # Updated to match naming convention
  Region        = "US1"
  Project       = "EM-NextGen"
  ManagedBy     = "Terraform"
  Purpose       = "Production-Walmart"
  Owner         = "CloudOps-Team"
  Architecture  = "Shared-Hub-Spoke"
  HubSharedWith = "CS-BOFA"
}
