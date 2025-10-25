# EM Complete Module - Unified Infrastructure Module
# Based on the Terraform Migration Strategy for EM NextGen Infrastructure

# Resource Group Module (conditional)
module "rg" {
  count  = var.create_rg ? 1 : 0
  source = "./rg"

  rg_name  = var.rg_name
  location = var.location
}

# Use existing resource group if not creating new one
data "azurerm_resource_group" "existing_rg" {
  count = var.create_rg ? 0 : 1
  name  = var.rg_name
}

# Local value to get the correct RG name regardless of creation method
locals {
  rg_name = var.create_rg ? module.rg[0].rg_name : data.azurerm_resource_group.existing_rg[0].name
}

# Networking Module (conditional)
module "networking" {
  count  = var.create_vnet ? 1 : 0
  source = "./networking"

  # Basic Configuration
  rg_name            = local.rg_name
  location           = var.location
  vnet_name          = var.vnet_name
  vnet_address_space = var.vnet_address_space
  subnets            = var.subnets

  # Additional Configuration
  tags = var.tags

  dns_servers = var.dns_servers
}

# Storage Account Module for PowerShell Scripts (only create if no external storage provided)
module "scripts_storage" {
  count  = length(var.virtual_machines) > 0 && var.external_scripts_storage_account_name == null ? 1 : 0
  source = "./storage-scripts"

  storage_account_name = lower(replace("${var.rg_name}scripts", "/[^a-zA-Z0-9]/", ""))
  resource_group_name  = local.rg_name
  location             = var.location
  container_name       = "powershell-scripts"

  allowed_subnet_ids = var.create_vnet ? values(module.networking[0].subnet_ids) : []

  tags = var.tags
}

# Key Vault Module (optional - only created if key vault is required)
module "keyvault" {
  count  = var.create_key_vault ? 1 : 0
  source = "./keyvault"

  key_vault_name      = var.key_vault_name != null ? var.key_vault_name : "${replace(var.vnet_name, "-VNET", "")}-KV"
  location            = var.location
  resource_group_name = local.rg_name

  tags = var.tags
}

# Compute Module (optional - only created if VMs are specified)
module "compute" {
  for_each = var.virtual_machines
  source   = "./compute"

  vm_name             = each.key
  location            = var.location
  resource_group_name = local.rg_name
  subnet_id           = var.create_vnet ? module.networking[0].subnet_ids[each.value.subnet_name] : lookup(var.external_subnet_ids, each.value.subnet_name, null)

  # VM Configuration
  vm_size            = each.value.vm_size
  admin_username     = each.value.admin_username
  windows_sku        = each.value.windows_sku
  os_disk_type       = each.value.os_disk_type
  os_disk_size_gb    = each.value.os_disk_size_gb
  enable_public_ip   = each.value.enable_public_ip
  allowed_rdp_source = each.value.allowed_rdp_source
  environment        = var.environment
  environment_code   = var.environment_code
  data_disks         = lookup(each.value, "data_disks", [])

  # Dependencies
  key_vault_id        = var.create_key_vault ? module.keyvault[0].key_vault_id : each.value.external_key_vault_id
  storage_account_uri = null # Boot diagnostics disabled

  # PowerShell Scripts Storage Account (use external if provided, otherwise internal)
  scripts_storage_account_name = var.external_scripts_storage_account_name != null ? var.external_scripts_storage_account_name : (length(module.scripts_storage) > 0 ? module.scripts_storage[0].storage_account_name : null)
  scripts_container_name       = var.external_scripts_container_name != null ? var.external_scripts_container_name : (length(module.scripts_storage) > 0 ? module.scripts_storage[0].container_name : null)
  scripts_blob_endpoint        = length(module.scripts_storage) > 0 ? module.scripts_storage[0].primary_blob_endpoint : null

  # VM Extensions
  enable_vm_extensions = lookup(each.value, "enable_vm_extensions", var.enable_vm_extensions)

  # Azure DevOps Agent Configuration
  install_ado_agent    = lookup(each.value, "install_ado_agent", false)
  ado_organization_url = var.ado_organization_url
  ado_deployment_pool  = lookup(each.value, "ado_deployment_pool", var.ado_deployment_pool)
  ado_pat_token        = var.ado_pat_token

  # App Server gMSA Configuration
  app_service_account = var.app_service_account

  tags = merge(var.tags, each.value.additional_tags)

  depends_on = [
    module.networking,
    module.keyvault,
    module.scripts_storage
  ]
}

# VPN Gateway Module (optional - only created if VPN gateway is required and GatewaySubnet exists)
module "vpn_gateway" {
  count  = var.create_vpn_gateway && contains(keys(var.subnets), "GatewaySubnet") ? 1 : 0
  source = "./vpn-gateway"

  gateway_name        = var.vpn_gateway_config.gateway_name != null ? var.vpn_gateway_config.gateway_name : "${replace(var.vnet_name, "-VNET", "")}-VGW"
  location            = var.location
  resource_group_name = local.rg_name
  gateway_subnet_id   = var.create_vnet ? module.networking[0].subnet_ids["GatewaySubnet"] : null
  key_vault_id        = var.create_key_vault ? module.keyvault[0].key_vault_id : null

  # VPN Gateway Configuration
  gateway_sku        = var.vpn_gateway_config.gateway_sku
  gateway_generation = var.vpn_gateway_config.gateway_generation
  active_active      = var.vpn_gateway_config.active_active
  enable_bgp         = var.vpn_gateway_config.enable_bgp
  availability_zones = var.vpn_gateway_config.availability_zones

  # Point-to-Site Configuration
  vpn_client_address_space = var.vpn_gateway_config.vpn_client_address_space
  vpn_client_protocols     = var.vpn_gateway_config.vpn_client_protocols

  # Azure AD Configuration
  aad_tenant_id         = var.vpn_gateway_config.aad_tenant_id
  aad_audience          = var.vpn_gateway_config.aad_audience
  aad_issuer            = var.vpn_gateway_config.aad_issuer
  root_certificate_data = var.vpn_gateway_config.root_certificate_data

  # Hub VNet information for connection instructions
  hub_vnet_address_space = var.vnet_address_space[0]

  tags = var.tags

  depends_on = [
    module.networking,
    module.keyvault
  ]
}

# VNet Peering Module for Azure AD Domain Services (optional)
module "vnet_peering" {
  count  = var.enable_aadds_peering ? 1 : 0
  source = "./vnet-peering"

  # Local VNet Configuration
  local_vnet_name           = var.vnet_name
  local_resource_group_name = local.rg_name

  # Azure AD Domain Services VNet Configuration
  aadds_vnet_name           = var.aadds_vnet_name
  aadds_vnet_resource_group = var.aadds_vnet_resource_group

  # Tags
  tags = var.tags

  depends_on = [
    module.networking
  ]
}

# NAT Gateway Module (optional - for outbound internet access)
module "nat_gateway" {
  count  = var.create_nat_gateway ? 1 : 0
  source = "./nat-gateway"

  nat_gateway_name    = var.nat_gateway_name != null ? var.nat_gateway_name : "${replace(var.vnet_name, "-VNET", "")}-NAT-GW"
  location            = var.location
  resource_group_name = local.rg_name

  # Get subnet IDs for specified subnet names
  subnet_ids = [
    for subnet_name in var.nat_gateway_subnet_names :
    (var.create_vnet ? module.networking[0].subnet_ids[subnet_name] : null)
  ]

  tags = var.tags

  depends_on = [
    module.networking
  ]
}

# Moved block to handle the identity resource moving from inside the module to outside
# This tells Terraform that the resource has moved, not been deleted and recreated
moved {
  from = module.application_gateway[0].azurerm_user_assigned_identity.appgw
  to   = azurerm_user_assigned_identity.appgw[0]
}

# Create User-assigned Managed Identity for Application Gateway (outside the module)
# This allows us to grant Key Vault access BEFORE the Application Gateway is created
resource "azurerm_user_assigned_identity" "appgw" {
  count = var.create_application_gateway ? 1 : 0

  name                = "${var.appgw_name != null ? var.appgw_name : "${replace(var.vnet_name, "-VNET", "")}-AGW"}-identity"
  location            = var.location
  resource_group_name = local.rg_name

  tags = var.tags
}

# Grant Application Gateway managed identity access to Key Vault
# This must be created BEFORE Application Gateway can access certificates
resource "azurerm_key_vault_access_policy" "appgw" {
  count = var.create_application_gateway && var.create_key_vault && var.appgw_use_internal_keyvault ? 1 : 0

  key_vault_id = module.keyvault[0].key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]

  depends_on = [
    module.keyvault,
    azurerm_user_assigned_identity.appgw
  ]
}

# Application Gateway Module (optional - only created if Application Gateway is required)
module "application_gateway" {
  count  = var.create_application_gateway ? 1 : 0
  source = "./application-gateway"

  appgw_name          = var.appgw_name != null ? var.appgw_name : "${replace(var.vnet_name, "-VNET", "")}-AGW"
  location            = var.location
  resource_group_name = local.rg_name
  subnet_id           = var.create_vnet ? module.networking[0].subnet_ids[var.appgw_subnet_name] : var.appgw_subnet_id

  # Application Gateway Configuration
  backend_ip_addresses = var.appgw_backend_ip_addresses
  sku_name             = var.appgw_sku_name
  sku_tier             = var.appgw_sku_tier
  capacity             = var.appgw_capacity
  availability_zones   = var.appgw_availability_zones

  # WAF Configuration
  enable_waf           = var.appgw_enable_waf
  waf_firewall_mode    = var.appgw_waf_firewall_mode
  waf_rule_set_type    = var.appgw_waf_rule_set_type
  waf_rule_set_version = var.appgw_waf_rule_set_version

  # Health Probe Configuration
  health_probe_host = var.appgw_health_probe_host

  # SSL Certificate Configuration (Key Vault or direct data)
  key_vault_id = var.appgw_key_vault_id != null ? var.appgw_key_vault_id : (var.create_key_vault && var.appgw_use_internal_keyvault ? module.keyvault[0].key_vault_id : null)
  key_vault_secret_id = var.appgw_ssl_certificate_name != null && var.create_key_vault && var.appgw_use_internal_keyvault ? "${module.keyvault[0].key_vault_uri}secrets/${var.appgw_ssl_certificate_name}" : (
    var.appgw_ssl_certificate_name != null && var.appgw_key_vault_id != null ? var.appgw_key_vault_secret_id : null
  )
  ssl_certificate_name     = var.appgw_ssl_certificate_name
  ssl_certificate_data     = var.appgw_ssl_certificate_data
  ssl_certificate_password = var.appgw_ssl_certificate_password

  # Backend HTTP Settings and Probes
  backend_http_settings_list = var.appgw_backend_http_settings_list
  probes_list                = var.appgw_probes_list

  # HTTP Listeners and Routing Rules
  http_listeners_list        = var.appgw_http_listeners_list
  request_routing_rules_list = var.appgw_request_routing_rules_list

  # Pass the externally-created managed identity to the module
  external_identity_id = azurerm_user_assigned_identity.appgw[0].id

  tags = var.tags

  depends_on = [
    module.networking,
    module.keyvault,
    azurerm_key_vault_access_policy.appgw,
    azurerm_user_assigned_identity.appgw
  ]
}

# Get current client configuration for tenant ID
data "azurerm_client_config" "current" {}
