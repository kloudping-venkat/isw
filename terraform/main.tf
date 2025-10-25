# EM NextGen Infrastructure - Multi-Environment
# Supports CS, Walmart, and future environments with flag-based deployment
#
# Module Versions:
# - modules/azure: v1.0.0 (networking, compute, keyvault, storage)
# - modules/azure/db: v1.0.0 (Oracle database)
# - modules/azure/sftp: v1.0.0 (SFTP with private endpoints)
# - Terraform: >= 1.5.0
# - AzureRM Provider: ~> 3.0
#
# Version Control:
# - CS: Use stable/cs-v1.0.0 branch or v1.0.0 tag
# - Walmart: Use master branch
# - See VERSIONING-IMPLEMENTATION.md for details

# Get current Azure client configuration for automatic tenant ID detection
data "azurerm_client_config" "current" {}

# Local values for dynamic naming
locals {
  prefix = "${upper(var.location_code)}-${upper(var.client)}-${upper(var.environment)}"

  # Hub subnets (all inside hub VNet) - Updated to match cs.tfvars configuration
  hub_subnets = {
    "GatewaySubnet" = {
      address_prefix    = "10.223.40.0/26"
      service_endpoints = []
    }
    "AzureBastionSubnet" = {
      address_prefix    = "10.223.40.64/26"
      service_endpoints = []
    }
    "SHARED-SERVICES-SUBNET" = {
      address_prefix    = "10.223.40.128/26"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }
    "MANAGEMENT-SUBNET" = {
      address_prefix    = "10.223.40.192/26"
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

# Create all Resource Groups following production naming pattern (parameterized for multi-environment)
resource "azurerm_resource_group" "environment_rgs" {
  for_each = toset(var.resource_groups)

  name     = "${local.prefix}-${each.key}"
  location = var.location
  tags     = var.tags
}

# ========================================
# HUB INFRASTRUCTURE (CS-HUB RG)
# Conditional: Disabled for Walmart (uses shared hub)
# ========================================
module "hub_infrastructure" {
  count  = var.enable_hub ? 1 : 0
  source = "./modules/azure"

  rg_name            = azurerm_resource_group.environment_rgs["HUB"].name
  location           = var.location
  vnet_name          = "${local.prefix}-HUB-VNET"
  vnet_address_space = [var.hub_vnet_address_space]
  subnets            = local.hub_subnets
  create_rg          = false

  # VPN Gateway Configuration (uses GatewaySubnet)
  create_vpn_gateway = true
  vpn_gateway_config = {
    gateway_name             = "${local.prefix}-HUB-VGW"
    gateway_sku              = "VpnGw2"
    gateway_generation       = "Generation2"
    active_active            = false
    enable_bgp               = false
    availability_zones       = [] # No AZ for CS environment - simpler deployment
    vpn_client_address_space = ["172.16.0.0/24"]
    vpn_client_protocols     = ["OpenVPN"]
    aad_tenant_id            = data.azurerm_client_config.current.tenant_id
    aad_audience             = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
    aad_issuer               = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"
    root_certificate_data    = null
  }

  # VNet Peering to Azure AD Domain Services (HUB connects to AADDS for domain join)
  enable_aadds_peering      = true
  aadds_vnet_name           = var.aadds_vnet_name
  aadds_vnet_resource_group = var.aadds_vnet_resource_group

  # Key Vault for Hub/VPN secrets
  create_key_vault = true
  key_vault_name   = "${local.prefix}-HUB-KV"

  dns_servers = var.dns_servers
  tags        = var.tags

  depends_on = [azurerm_resource_group.environment_rgs]
}

# ========================================
# SPOKE VNET - Always created for all environments
# ========================================
module "spoke_vnet" {
  source = "./modules/azure"

  rg_name            = azurerm_resource_group.environment_rgs["SPOKE"].name
  location           = var.location
  vnet_name          = "${local.prefix}-SPOKE-VNET"
  vnet_address_space = [var.spoke_vnet_address_space]
  subnets            = var.spoke_subnets
  create_rg          = false
  dns_servers        = var.dns_servers

  # NAT Gateway for internet access (enable for private VM internet access)
  create_nat_gateway       = true
  nat_gateway_subnet_names = ["${local.prefix}-SPOKE-WEB-SUBNET", "${local.prefix}-SPOKE-APP-SUBNET", "${local.prefix}-SPOKE-ADO-SUBNET"]

  # VNet Peering to Azure AD Domain Services (SPOKE connects to AADDS for domain join)
  enable_aadds_peering      = true
  aadds_vnet_name           = var.aadds_vnet_name
  aadds_vnet_resource_group = var.aadds_vnet_resource_group

  tags = var.tags

  depends_on = [azurerm_resource_group.environment_rgs]
}

# ========================================
# SFTP INFRASTRUCTURE (SFTP RG)
# Conditional: Control via enable_sftp flag
# ========================================
module "sftp" {
  count  = var.enable_sftp ? 1 : 0
  source = "./modules/azure/sftp"

  rg_name  = azurerm_resource_group.environment_rgs["SFTP"].name
  location = var.location

  # SFTP Storage Account
  create_sftp_storage  = var.enable_sftp
  storage_account_name = "${lower(var.location_code)}${lower(var.client)}${lower(var.environment)}sftpng" # ng = NextGen
  account_kind         = "BlockBlobStorage"
  account_tier         = "Premium"
  replication_type     = "LRS"
  access_tier          = "Hot" # Ignored for BlockBlobStorage

  # Network Security
  public_network_access_enabled = true    # Must be true for Terraform to create containers
  network_default_action        = "Allow" # Temporarily Allow for initial setup, change to Deny after deployment
  allowed_subnet_ids            = [module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-SFTP-SUBNET"]]
  allowed_ip_addresses          = [] # Add specific IPs if needed

  # Blob properties (versioning disabled - incompatible with HNS/SFTP)
  enable_versioning               = false # Cannot be enabled with is_hns_enabled (SFTP requirement)
  enable_change_feed              = true
  enable_managed_identity         = false # Disabled to avoid BadRequest during initial creation
  blob_delete_retention_days      = 30
  container_delete_retention_days = 30

  # Containers
  containers = {
    "uploads"   = {}
    "downloads" = {}
    "archive"   = {}
  }

  # Networking
  subnet_name = "SFTP-SUBNET"
  vnet_id     = module.spoke_vnet.vnet_id
  vnet_name   = "${local.prefix}-SPOKE-VNET"

  # NAT Gateway
  create_nat_gateway   = var.enable_sftp
  nat_gateway_name     = "${local.prefix}-SFTP-NATGW01"
  nat_gateway_pip_name = "${local.prefix}-SFTP-NATGWPIP01"
  nat_idle_timeout     = 10
  availability_zones   = ["1"]
  sftp_subnet_id       = module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-SFTP-SUBNET"]

  # Private Endpoint
  create_private_endpoint = var.enable_sftp
  private_endpoint_name   = "${lower(var.location_code)}${lower(var.client)}${lower(var.environment)}sftp-blob-pe"
  create_private_dns_zone = var.enable_sftp

  # Network Security Group - Disable since networking module already creates NSG for SFTP-SUBNET
  create_sftp_nsg         = false # Networking module handles NSG
  sftp_allowed_source_ips = []    # Not used when create_sftp_nsg = false

  # Azure Firewall (optional - enable via var.enable_sftp_firewall)
  create_firewall    = var.enable_sftp_firewall
  firewall_name      = var.enable_sftp_firewall ? "${local.prefix}-SFTP-FW01" : ""
  firewall_pip_name  = var.enable_sftp_firewall ? "${local.prefix}-SFTP-FWPIP01" : ""
  firewall_sku_tier  = "Standard"
  firewall_subnet_id = null # TODO: Add AzureFirewallSubnet when enabling firewall

  # Automation Account (optional - enable via var.enable_sftp_automation)
  create_automation_account     = var.enable_sftp_automation
  automation_account_name       = var.enable_sftp_automation ? "${local.prefix}-SFTP-AUTO" : ""
  enable_automation_schedule    = var.enable_sftp_automation
  automation_schedule_frequency = "Hour"
  automation_schedule_interval  = 4
  automation_source_container   = "uploads"
  automation_destination_path   = "" # Update with SMB share path when enabling

  # Monitoring (add if Log Analytics workspace exists)
  log_analytics_workspace_id = null

  tags = var.tags

  depends_on = [module.spoke_vnet]
}

# ========================================
# SHARED STORAGE ACCOUNT FOR SCRIPTS - REMOVED
# ========================================
# Storage account removed - PowerShell scripts are now embedded directly in VM extensions

# ========================================
# WEB TIER RESOURCES (CS-WEB RG)
# Conditional: Control via enable_web_vms flag
# ========================================
module "web_resources" {
  count  = var.enable_web_vms ? 1 : 0
  source = "./modules/azure"

  rg_name  = azurerm_resource_group.environment_rgs["WEB"].name
  location = var.location
  # Don't create VNet or networking resources
  vnet_name          = ""
  vnet_address_space = []
  subnets            = {}
  environment        = var.environment
  environment_code   = var.environment_code != "" ? var.environment_code : var.environment
  create_rg          = false
  create_vnet        = false

  # Pass subnet IDs from spoke_vnet module
  external_subnet_ids = module.spoke_vnet.subnet_ids

  # Scripts are embedded directly in VM extensions - no external storage needed

  # Key Vault for WEB tier secrets
  create_key_vault = true
  key_vault_name   = "${local.prefix}-WEB-KV"

  # Enable VM extensions for this module
  enable_vm_extensions = true

  # ADO configuration for deployment pool agents
  ado_organization_url = var.ado_organization_url
  ado_deployment_pool  = var.ado_deployment_pool
  ado_pat_token        = var.ado_pat_token

  # Application Gateway Configuration
  create_application_gateway = true
  appgw_name                 = "${local.prefix}-WEB-AGW"
  appgw_subnet_id            = module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-AG-SUBNET"]
  appgw_backend_ip_addresses = [
    # Dynamically populated with WEB VM private IPs
    for vm_name, vm_info in module.web_resources[0].virtual_machines : vm_info.vm_private_ip
  ]
  appgw_sku_name             = "WAF_v2"
  appgw_sku_tier             = "WAF_v2"
  appgw_capacity             = 2
  appgw_availability_zones   = ["1", "2", "3"]
  appgw_enable_waf           = true
  appgw_waf_firewall_mode    = "Detection"
  appgw_waf_rule_set_type    = "OWASP"
  appgw_waf_rule_set_version = "3.2"
  appgw_health_probe_host    = "127.0.0.1"

  # SSL Certificate from Key Vault - STAGE 2: ENABLED
  appgw_use_internal_keyvault = true
  appgw_ssl_certificate_name  = "starcertentcom2025"

  # Health Probes - Configured via tfvars per environment
  appgw_probes_list = var.appgw_probes_list

  # Backend HTTP Settings - Configured via tfvars per environment
  appgw_backend_http_settings_list = var.appgw_backend_http_settings_list

  # HTTP Listeners - Configured via tfvars per environment
  appgw_http_listeners_list = var.appgw_http_listeners_list

  # Routing Rules - Configured via tfvars per environment
  appgw_request_routing_rules_list = var.appgw_request_routing_rules_list

  # WEB Virtual Machines (reference subnet from spoke_vnet module)
  virtual_machines = {
    "${local.prefix}-WEB-VM01" = {
      subnet_name        = "${local.prefix}-SPOKE-WEB-SUBNET"
      vm_size            = "Standard_B4ms"
      admin_username     = "webadmin"
      windows_sku        = "2022-datacenter-azure-edition-hotpatch"
      os_disk_type       = "Premium_LRS"
      os_disk_size_gb    = 128
      enable_public_ip   = false
      allowed_rdp_source = "VirtualNetwork"
      data_disks = [
        { size_gb = 128, drive_letter = "F", lun = 0 },
        { size_gb = 50, drive_letter = "R", lun = 1 }
      ]
      additional_tags = { Role = "WebServer", Tier = "Web", Application = "IIS" }

      # Azure DevOps Agent Configuration
      install_ado_agent   = true
      ado_deployment_pool = var.ado_deployment_pool
    }
  }

  tags = var.tags

  depends_on = [azurerm_resource_group.environment_rgs]
}


# ========================================
# APP TIER RESOURCES (CS-APP RG)
# Conditional: Control via enable_app_vms flag
# ========================================
module "app_resources" {
  count  = var.enable_app_vms ? 1 : 0
  source = "./modules/azure"

  rg_name  = azurerm_resource_group.environment_rgs["APP"].name
  location = var.location
  # Don't create VNet or networking resources
  vnet_name          = ""
  vnet_address_space = []
  subnets            = {}
  environment        = var.environment
  environment_code   = var.environment_code != "" ? var.environment_code : var.environment
  create_rg          = false
  create_vnet        = false

  # Pass subnet IDs from spoke_vnet module
  external_subnet_ids = module.spoke_vnet.subnet_ids

  # Scripts are embedded directly in VM extensions - no external storage needed

  # Key Vault for APP tier secrets
  create_key_vault = true
  key_vault_name   = "${local.prefix}-APP-KV"

  # Enable VM extensions for this module
  enable_vm_extensions = true

  # ADO configuration for deployment pool agents
  ado_organization_url = var.ado_organization_url
  ado_deployment_pool  = var.ado_deployment_pool
  ado_pat_token        = var.ado_pat_token

  # App Server gMSA Configuration
  app_service_account = var.app_service_account

  # APP Virtual Machines (reference subnet from spoke_vnet module)
  virtual_machines = {
    "${local.prefix}-APP-VM01" = {
      subnet_name        = "${local.prefix}-SPOKE-APP-SUBNET"
      vm_size            = "Standard_B4ms"
      admin_username     = "appadmin"
      windows_sku        = "2022-datacenter-azure-edition-hotpatch"
      os_disk_type       = "Premium_LRS"
      os_disk_size_gb    = 128
      enable_public_ip   = false
      allowed_rdp_source = "VirtualNetwork"
      data_disks = [
        { size_gb = 128, drive_letter = "E", lun = 0 },
        { size_gb = 50, drive_letter = "R", lun = 1 }
      ]
      additional_tags = { Role = "ApplicationServer", Tier = "App", Application = "AppServices" }

      # Azure DevOps Agent Configuration
      install_ado_agent   = true
      ado_deployment_pool = var.ado_deployment_pool
    }
  }

  tags = var.tags

  depends_on = [azurerm_resource_group.environment_rgs]
}

# ========================================
# DB TIER RESOURCES (CS-DB RG)
# Conditional: Control via enable_db_vms flag
# ========================================

# Random password for Oracle database admin - VM01
resource "random_password" "oracle_admin_password_01" {
  count   = var.enable_db_vms && var.enable_db_vm_01 ? 1 : 0
  length  = 16
  special = true
}

# Oracle Database Server - VM01
# Used by Walmart and other environments that need DB-VM01
module "db_resources_01" {
  count  = var.enable_db_vms && var.enable_db_vm_01 ? 1 : 0
  source = "./modules/azure/db"

  # Basic Configuration
  vm_name   = "${local.prefix}-DB-VM01"
  location  = var.location
  rg_name   = azurerm_resource_group.environment_rgs["DB"].name
  subnet_id = module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-DB-SUBNET"]

  # VM Configuration - E4ds_v4 supports 8 data disks
  vm_size                         = var.db_vm_size != null ? var.db_vm_size : "Standard_E4ds_v4"
  admin_username                  = "oracle"
  admin_password                  = random_password.oracle_admin_password_01[0].result
  ssh_public_key                  = var.ssh_public_key
  disable_password_authentication = false

  # Storage Configuration
  os_disk_storage_type = "Premium_LRS"
  disk_storage_type    = "Premium_LRS"

  # Oracle Configuration
  oracle_linux_version = "ol95-lvm-gen2"
  # Enable cloud-init for fresh installs AND data-disk-only restores
  # Disable only for full VM restores (where OS disk already has everything)
  enable_oracle_prep   = var.db_restore_from_snapshot && !var.db_restore_data_disks_only ? false : var.db_enable_oracle_prep

  # Network Configuration - Create NSG only when this module is enabled
  spoke_vnet_address_space = var.spoke_vnet_address_space
  create_nsg               = true # VM01 creates NSG (same name used by both)
  network_security_group_id = null

  # Key Vault Configuration
  key_vault_id             = module.db_key_vault[0].key_vault_id
  create_key_vault_secrets = true

  # Snapshot Restore Configuration
  restore_from_snapshot         = var.db_restore_from_snapshot
  restore_data_disks_only       = var.db_restore_data_disks_only
  source_vm_id                  = var.db_source_vm_id
  source_vm_restore_point_id    = var.db_source_vm_restore_point_id
  source_os_disk_snapshot_id    = var.db_source_os_disk_snapshot_id
  source_data_disk_snapshot_ids = var.db_source_data_disk_snapshot_ids
  snapshot_subscription_id      = var.db_snapshot_subscription_id
  snapshot_resource_group       = var.db_snapshot_resource_group

  # Naming Configuration
  location_code = var.location_code
  client        = var.client
  environment   = var.environment

  tags = merge(var.tags, {
    Role     = "DatabaseServer"
    Tier     = "Database"
    Purpose  = "Oracle Database Server"
    Instance = "DB-VM01"
  })

  depends_on = [
    azurerm_resource_group.environment_rgs,
    module.db_key_vault
  ]
}

# Random password for Oracle database admin - VM02
resource "random_password" "oracle_admin_password_02" {
  count   = var.enable_db_vms && var.enable_db_vm_02 ? 1 : 0
  length  = 16
  special = true
}

# Oracle Database Server - VM02
# CS: Uses VM02 (VM01 was destroyed)
# Other envs: Can use different module names for VM01, VM03, etc.
module "db_resources_02" {
  count  = var.enable_db_vms && var.enable_db_vm_02 ? 1 : 0
  source = "./modules/azure/db"

  # Basic Configuration
  vm_name   = "${local.prefix}-DB-VM02"
  location  = var.location
  rg_name   = azurerm_resource_group.environment_rgs["DB"].name
  subnet_id = module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-DB-SUBNET"]

  # VM Configuration - E4ds_v4 supports 8 data disks
  vm_size                         = var.db_vm_size != null ? var.db_vm_size : "Standard_E4ds_v4" # 4 vCPUs, 32GB RAM, supports 8 data disks
  admin_username                  = "oracle"
  admin_password                  = random_password.oracle_admin_password_02[0].result
  ssh_public_key                  = var.ssh_public_key
  disable_password_authentication = false

  # Storage Configuration
  os_disk_storage_type = "Premium_LRS"
  disk_storage_type    = "Premium_LRS"

  # Oracle Configuration
  oracle_linux_version = "ol95-lvm-gen2"
  # Enable cloud-init for fresh installs AND data-disk-only restores
  # Disable only for full VM restores (where OS disk already has everything)
  # Use DB-VM02-specific restore flag for this instance
  enable_oracle_prep   = var.db_vm_02_restore_from_snapshot && !var.db_vm_02_restore_data_disks_only ? false : var.db_vm_02_enable_oracle_prep

  # Network Configuration - Use NSG from VM01 if enabled, otherwise create own
  spoke_vnet_address_space      = var.spoke_vnet_address_space
  create_nsg                     = var.enable_db_vm_01 ? false : true # Create NSG only if VM01 disabled
  network_security_group_id      = var.enable_db_vm_01 ? module.db_resources_01[0].network_security_group_id : null # Use NSG from VM01 if enabled

  # Key Vault Configuration (create dedicated Key Vault for DB secrets)
  key_vault_id             = module.db_key_vault[0].key_vault_id
  create_key_vault_secrets = true

  # Snapshot Restore Configuration (optional) - Using DB-VM02-specific variables
  restore_from_snapshot         = var.db_vm_02_restore_from_snapshot
  restore_data_disks_only       = var.db_vm_02_restore_data_disks_only
  source_vm_id                  = null  # DB-VM02 specific: use restore point ID instead
  source_vm_restore_point_id    = var.db_vm_02_source_vm_restore_point_id
  source_os_disk_snapshot_id    = var.db_vm_02_source_os_disk_snapshot_id  # Full VM restore: OS disk included
  source_data_disk_snapshot_ids = var.db_vm_02_source_data_disk_snapshot_ids
  snapshot_subscription_id      = var.db_vm_02_snapshot_subscription_id
  snapshot_resource_group       = var.db_vm_02_snapshot_resource_group

  # Naming Configuration
  location_code = var.location_code
  client        = var.client
  environment   = var.environment

  tags = merge(var.tags, {
    Role     = "DatabaseServer"
    Tier     = "Database"
    Purpose  = "Oracle Database Server"
    Instance = "DB-VM02"
  })

  depends_on = [
    azurerm_resource_group.environment_rgs,
    module.spoke_vnet,
    module.db_key_vault
  ]
}

# Dedicated Key Vault for Database secrets
module "db_key_vault" {
  count  = var.enable_db_vms ? 1 : 0
  source = "./modules/azure"

  rg_name            = azurerm_resource_group.environment_rgs["DB"].name
  location           = var.location
  vnet_name          = ""
  vnet_address_space = []
  subnets            = {}
  environment        = var.environment
  create_rg          = false
  create_vnet        = false

  # Key Vault for DB tier secrets
  create_key_vault = true
  key_vault_name   = "${local.prefix}-DB-KV"

  tags = var.tags

  depends_on = [azurerm_resource_group.environment_rgs]
}

# ========================================
# ADO AGENTS RESOURCES (CS-ADO RG)
# Conditional: Control via enable_ado_vms flag
# ========================================
module "ado_resources" {
  count  = var.enable_ado_vms ? 1 : 0
  source = "./modules/azure"

  rg_name  = azurerm_resource_group.environment_rgs["ADO"].name
  location = var.location
  # Don't create VNet or networking resources
  vnet_name          = ""
  vnet_address_space = []
  subnets            = {}
  environment        = var.environment
  environment_code   = var.environment_code != "" ? var.environment_code : var.environment
  create_rg          = false
  create_vnet        = false

  # Pass subnet IDs from spoke_vnet module
  external_subnet_ids = module.spoke_vnet.subnet_ids

  # Scripts are embedded directly in VM extensions - no external storage needed

  # Key Vault for ADO tier secrets
  create_key_vault = true
  key_vault_name   = "${local.prefix}-ADO-KV"

  # Enable VM extensions for this module
  enable_vm_extensions = true

  # ADO configuration for deployment pool agents
  ado_organization_url = var.ado_organization_url
  ado_deployment_pool  = var.ado_deployment_pool
  ado_pat_token        = var.ado_pat_token

  # ADO Agent Virtual Machines (reference subnet from spoke_vnet module)
  virtual_machines = {
    "${local.prefix}-ADO-VM01" = {
      subnet_name        = "${local.prefix}-SPOKE-ADO-SUBNET"
      vm_size            = "Standard_B4ms"
      admin_username     = "adoadmin"
      windows_sku        = "2022-datacenter-azure-edition-hotpatch"
      os_disk_type       = "Premium_LRS"
      os_disk_size_gb    = 128
      enable_public_ip   = false
      allowed_rdp_source = "VirtualNetwork"
      data_disks = [
        { size_gb = 128, drive_letter = "E", lun = 0 },
        { size_gb = 128, drive_letter = "R", lun = 1 }
      ]
      additional_tags = {
        Role    = "ADOAgent"
        Purpose = "Azure DevOps Build Agent"
        Tier    = "DevOps"
      }

      # Azure DevOps Agent Configuration
      install_ado_agent   = true
      ado_deployment_pool = var.ado_deployment_pool

      external_key_vault_id = null
    }
  }

  tags = var.tags

  depends_on = [azurerm_resource_group.environment_rgs]
}

# ========================================
# VNET PEERING (Hub-Spoke Architecture)
# Handles both dedicated hub and shared hub scenarios
# ========================================

# Data source for shared hub (Walmart uses CS hub)
data "azurerm_virtual_network" "shared_hub" {
  count               = var.use_shared_hub ? 1 : 0
  name                = var.shared_hub_vnet_name
  resource_group_name = var.shared_hub_vnet_resource_group
}

# Hub to Spoke VNet Peering
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = var.use_shared_hub ? "CS-HUB-TO-${upper(var.client)}-SPOKE" : "${local.prefix}-HUB-TO-SPOKE-PEERING"
  resource_group_name          = var.use_shared_hub ? var.shared_hub_vnet_resource_group : azurerm_resource_group.environment_rgs["HUB"].name
  virtual_network_name         = var.use_shared_hub ? var.shared_hub_vnet_name : module.hub_infrastructure[0].vnet_name
  remote_virtual_network_id    = module.spoke_vnet.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false

  depends_on = [module.hub_infrastructure, module.spoke_vnet]
}

# Spoke to Hub VNet Peering
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "${local.prefix}-SPOKE-TO-HUB-PEERING"
  resource_group_name          = azurerm_resource_group.environment_rgs["SPOKE"].name
  virtual_network_name         = module.spoke_vnet.vnet_name
  remote_virtual_network_id    = var.use_shared_hub ? data.azurerm_virtual_network.shared_hub[0].id : module.hub_infrastructure[0].vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true

  depends_on = [module.hub_infrastructure, module.spoke_vnet]
}

# ========================================
# LOGI ANALYTICS PLATFORM - AKS CLUSTER (CS-LOGI RG)
# ========================================
# TEMPORARILY DISABLED - FIXING VM EXTENSIONS FIRST
# module "logi_aks" {
#   source = "./modules/em/aks"
#
#   # Basic Configuration
#   cluster_name = "${local.prefix}-LOGI-AKS"
#   rg_name      = azurerm_resource_group.environment_rgs["LOGI"].name
#   location     = var.location
#   subnet_id    = module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-LOGI-SUBNET"]
#
#   # Environment Configuration
#   location_code = var.location_code
#   client        = var.client
#   environment   = var.environment
#
#   # Kubernetes Configuration
#   kubernetes_version = var.kubernetes_version
#
#   # Default Node Pool (System) - Optimized for CS environment
#   default_node_pool = {
#     name                   = "system"
#     vm_size               = "Standard_B4ms"  # 4 vCPUs, 16GB RAM
#     availability_zones    = []                 # No AZ for CS environment - simpler and more reliable
#     enable_auto_scaling   = true
#     max_count             = 5
#     min_count             = 2
#     node_count            = 2
#     os_disk_size_gb       = 128
#     os_disk_type          = "Managed"
#     ultra_ssd_enabled     = false
#     node_labels           = { "nodepool-type" = "system", "environment" = var.environment }
#     node_taints           = []
#     enable_host_encryption = false
#     max_pods              = 110
#   }
#
#   # Additional Node Pool for Logi Symphony workloads
#   additional_node_pools = var.enable_logi_dedicated_nodes ? {
#     "logi" = {
#       vm_size               = "Standard_D8s_v3"  # 8 vCPUs, 32GB RAM for Logi workloads
#       availability_zones    = []                 # No AZ for CS environment - simpler and more reliable
#       enable_auto_scaling   = true
#       max_count             = 8
#       min_count             = 2
#       node_count            = 3
#       os_disk_size_gb       = 256
#       os_disk_type          = "Managed"
#       node_labels          = {
#         "nodepool-type" = "logi",
#         "workload" = "analytics",
#         "environment" = var.environment
#       }
#       node_taints          = var.logi_node_taints
#       enable_host_encryption = false
#       max_pods             = 110
#     }
#   } : {}
#
#   # Authentication (Azure AD Integration)
#   admin_group_object_ids = var.aks_admin_group_object_ids
#   azure_rbac_enabled     = true
#   local_account_disabled = var.aks_disable_local_accounts
#
#   # Security Configuration
#   private_cluster_enabled             = var.aks_private_cluster_enabled
#   private_cluster_public_fqdn_enabled = var.aks_private_cluster_public_fqdn_enabled
#
#   # Add-ons Configuration
#   enable_log_analytics_workspace = var.enable_aks_log_analytics
#   enable_microsoft_defender       = var.enable_aks_microsoft_defender
#   enable_azure_policy            = var.enable_aks_azure_policy
#
#   # External Container Registry (connect to existing registry instead of creating new one)
#   external_container_registry = var.external_logi_container_registry
#
#   # Logi Symphony Namespace
#   create_logi_namespace = true
#   logi_namespace_name   = var.logi_namespace_name
#
#   # Network Configuration
#   network_plugin = "azure"  # Azure CNI for production workloads
#   network_policy = "azure"  # Azure Network Policy for security
#
#   # Route Table Configuration - Disabled for public IP approach
#   create_aks_route_table = false  # Let AKS use default routes with public IPs
#
#   tags = merge(var.tags, {
#     Purpose     = "Logi Analytics Platform"
#     Tier        = "Analytics"
#     Application = "Logi Symphony"
#   })
#
#   depends_on = [
#     azurerm_resource_group.environment_rgs,
#     module.spoke_vnet
#   ]
# }