# EM Module Variables

# Basic Configuration
variable "location" {
  type        = string
  description = "Azure region"
}

# Resource Group
variable "rg_name" {
  type        = string
  description = "Name of the resource group"
}

variable "create_rg" {
  type        = bool
  description = "Whether to create the resource group or use existing one"
  default     = true
}

variable "create_vnet" {
  type        = bool
  description = "Whether to create the virtual network or skip networking entirely"
  default     = true
}

# Network Configuration
variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "CIDR blocks for the VNet"
}

variable "subnets" {
  type = map(object({
    address_prefix    = string
    service_endpoints = optional(list(string), [])
  }))
  description = "Map of subnets with their configuration"
}

# Environment
variable "environment" {
  type        = string
  description = "Environment name (e.g., CS, PROD, DEV)"
  default     = "CS"
}

variable "environment_code" {
  type        = string
  description = "Short environment code for computer names (e.g., CS, WM, PROD)"
  default     = "CS"
}

# VNet Peering Configuration for Azure AD Domain Services
variable "enable_aadds_peering" {
  type        = bool
  description = "Enable VNet peering to Azure AD Domain Services VNet"
  default     = false
}

variable "aadds_vnet_name" {
  type        = string
  description = "Name of the Azure AD Domain Services VNet"
  default     = "US1-BOFA-P-DS-VNET"
}

variable "aadds_vnet_resource_group" {
  type        = string
  description = "Resource group containing the Azure AD Domain Services VNet"
  default     = "US1-BOFA-P-DS"
}

# Key Vault Configuration
variable "create_key_vault" {
  type        = bool
  description = "Whether to create a Key Vault"
  default     = false
}

variable "key_vault_name" {
  type        = string
  description = "Name of the Key Vault (optional - will be auto-generated if not provided)"
  default     = null
}

# Virtual Machines Configuration
variable "virtual_machines" {
  type = map(object({
    subnet_name           = string
    vm_size               = optional(string, "Standard_B2ms")
    admin_username        = optional(string, "vmadmin")
    windows_sku           = optional(string, "2022-datacenter-azure-edition")
    os_disk_type          = optional(string, "Premium_LRS")
    os_disk_size_gb       = optional(number, 128)
    enable_public_ip      = optional(bool, false)
    allowed_rdp_source    = optional(string, "VirtualNetwork")
    external_key_vault_id = optional(string, null)
    additional_tags       = optional(map(string), {})
    data_disks = optional(list(object({
      size_gb      = number
      drive_letter = string
      lun          = number
    })), [])
    install_ado_agent = optional(bool, false)
    ado_agent_tags    = optional(string, "")
  }))
  description = "Map of virtual machines to create"
  default     = {}
}

# VPN Gateway Configuration
variable "create_vpn_gateway" {
  type        = bool
  description = "Whether to create a VPN Gateway in GatewaySubnet"
  default     = false
}

variable "vpn_gateway_config" {
  type = object({
    gateway_name             = optional(string, null)
    gateway_sku              = optional(string, "VpnGw2")
    gateway_generation       = optional(string, "Generation2")
    active_active            = optional(bool, false)
    enable_bgp               = optional(bool, false)
    availability_zones       = optional(list(string), []) # No AZ for CS environment - simpler deployment
    vpn_client_address_space = optional(list(string), ["172.16.0.0/24"])
    vpn_client_protocols     = optional(list(string), ["OpenVPN"])
    aad_tenant_id            = string
    aad_audience             = optional(string, "41b23e61-6c1e-4545-b367-cd054e0ed4b4")
    aad_issuer               = string
    root_certificate_data    = optional(string, null)
  })
  description = "VPN Gateway configuration"
  default = {
    aad_tenant_id = ""
    aad_issuer    = ""
  }
}

# Tags
variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

variable "dns_servers" {
  type        = list(string)
  description = "List of custom DNS servers for the VNet"
  default     = []
}

# NAT Gateway Configuration
variable "create_nat_gateway" {
  description = "Create NAT Gateway for outbound internet access"
  type        = bool
  default     = false
}

variable "nat_gateway_name" {
  description = "Name of the NAT Gateway"
  type        = string
  default     = null
}

variable "nat_gateway_subnet_names" {
  description = "List of subnet names to associate with NAT Gateway"
  type        = list(string)
  default     = []
}

variable "external_subnet_ids" {
  description = "Map of external subnet IDs to use for VMs when not creating VNet"
  type        = map(string)
  default     = {}
}

# External Storage Configuration (for shared storage)
variable "external_scripts_storage_account_name" {
  description = "Name of external storage account for VM scripts (when using shared storage)"
  type        = string
  default     = null
}

variable "external_scripts_container_name" {
  description = "Name of external storage container for VM scripts (when using shared storage)"
  type        = string
  default     = null
}

# Azure DevOps Configuration
variable "ado_organization_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = ""
}

variable "ado_deployment_pool" {
  description = "Azure DevOps deployment pool name"
  type        = string
  default     = ""
}

variable "ado_pat_token" {
  description = "Azure DevOps PAT token (passed from pipeline)"
  type        = string
  sensitive   = true
  default     = ""
}

# App Server gMSA Configuration
variable "app_service_account" {
  description = "gMSA service account for APP servers"
  type        = string
  default     = null
}

# VM Extensions Configuration
variable "enable_vm_extensions" {
  description = "Enable VM extensions by default for all VMs"
  type        = bool
  default     = true
}

# Application Gateway Configuration
variable "create_application_gateway" {
  description = "Create Application Gateway"
  type        = bool
  default     = false
}

variable "appgw_name" {
  description = "Name of the Application Gateway (if null, will be auto-generated)"
  type        = string
  default     = null
}

variable "appgw_subnet_name" {
  description = "Name of the subnet for Application Gateway (when using internal VNet)"
  type        = string
  default     = "ApplicationGatewaySubnet"
}

variable "appgw_subnet_id" {
  description = "ID of the subnet for Application Gateway (when using external subnet)"
  type        = string
  default     = null
}

variable "appgw_backend_ip_addresses" {
  description = "List of backend IP addresses for Application Gateway"
  type        = list(string)
  default     = []
}

variable "appgw_sku_name" {
  description = "SKU name for Application Gateway"
  type        = string
  default     = "WAF_v2"
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku_name)
    error_message = "The appgw_sku_name must be either Standard_v2 or WAF_v2."
  }
}

variable "appgw_sku_tier" {
  description = "SKU tier for Application Gateway"
  type        = string
  default     = "WAF_v2"
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku_tier)
    error_message = "The appgw_sku_tier must be either Standard_v2 or WAF_v2."
  }
}

variable "appgw_capacity" {
  description = "Capacity (number of instances) for Application Gateway"
  type        = number
  default     = 2
  validation {
    condition     = var.appgw_capacity >= 1 && var.appgw_capacity <= 125
    error_message = "The appgw_capacity must be between 1 and 125."
  }
}

variable "appgw_availability_zones" {
  description = "Availability zones for Application Gateway"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "appgw_enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "appgw_waf_firewall_mode" {
  description = "WAF firewall mode"
  type        = string
  default     = "Detection"
  validation {
    condition     = contains(["Detection", "Prevention"], var.appgw_waf_firewall_mode)
    error_message = "The appgw_waf_firewall_mode must be either Detection or Prevention."
  }
}

variable "appgw_waf_rule_set_type" {
  description = "WAF rule set type"
  type        = string
  default     = "OWASP"
}

variable "appgw_waf_rule_set_version" {
  description = "WAF rule set version"
  type        = string
  default     = "3.2"
}

variable "appgw_health_probe_host" {
  description = "Host for health probe"
  type        = string
  default     = "127.0.0.1"
}

variable "appgw_ssl_certificate_data" {
  description = "SSL certificate data (base64 encoded) - legacy method"
  type        = string
  default     = null
  sensitive   = true
}

variable "appgw_ssl_certificate_password" {
  description = "SSL certificate password - legacy method"
  type        = string
  default     = null
  sensitive   = true
}

variable "appgw_key_vault_id" {
  description = "Resource ID of an external Key Vault containing SSL certificates (leave null to use internal Key Vault)"
  type        = string
  default     = null
}

variable "appgw_key_vault_secret_id" {
  description = "Full secret ID/URI of the SSL certificate in external Key Vault (only used with external Key Vault)"
  type        = string
  default     = null
}

variable "appgw_ssl_certificate_name" {
  description = "Name of the SSL certificate/secret in Key Vault"
  type        = string
  default     = null
}

variable "appgw_use_internal_keyvault" {
  description = "Use the Key Vault created by this module for Application Gateway certificates"
  type        = bool
  default     = false
}

variable "appgw_backend_http_settings_list" {
  description = "Map of backend HTTP settings configurations"
  type = map(object({
    port                  = number
    protocol              = string
    cookie_based_affinity = string
    request_timeout       = optional(number, 300)
    probe_name            = string
  }))
  default = {}
}

variable "appgw_probes_list" {
  description = "Map of health probe configurations"
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

variable "appgw_http_listeners_list" {
  description = "Map of HTTP listener configurations"
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

variable "appgw_request_routing_rules_list" {
  description = "Map of request routing rule configurations"
  type = map(object({
    rule_type                  = optional(string, "Basic")
    http_listener_name         = string
    backend_address_pool_name  = string
    backend_http_settings_name = string
    priority                   = number
  }))
  default = {}
}
