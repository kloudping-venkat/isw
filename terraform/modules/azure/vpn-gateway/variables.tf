# VPN Gateway Module Variables

variable "gateway_name" {
  type        = string
  description = "Name of the VPN Gateway"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "gateway_subnet_id" {
  type        = string
  description = "ID of the GatewaySubnet"
}

variable "key_vault_id" {
  type        = string
  description = "ID of the Key Vault to store VPN configuration"
}

variable "gateway_sku" {
  type        = string
  description = "SKU of the VPN Gateway"
  default     = "VpnGw2"
  validation {
    condition     = contains(["Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.gateway_sku)
    error_message = "The gateway_sku must be a valid VPN Gateway SKU."
  }
}

variable "gateway_generation" {
  type        = string
  description = "Generation of the VPN Gateway"
  default     = "Generation2"
  validation {
    condition     = contains(["Generation1", "Generation2"], var.gateway_generation)
    error_message = "The gateway_generation must be either Generation1 or Generation2."
  }
}

variable "active_active" {
  type        = bool
  description = "Enable active-active configuration"
  default     = false
}

variable "enable_bgp" {
  type        = bool
  description = "Enable BGP"
  default     = false
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for the VPN Gateway"
  default     = ["1", "2", "3"]
}

# Point-to-Site Configuration
variable "vpn_client_address_space" {
  type        = list(string)
  description = "Address space for VPN clients"
  default     = ["172.16.0.0/24"]
}

variable "vpn_client_protocols" {
  type        = list(string)
  description = "VPN client protocols"
  default     = ["OpenVPN"]
  validation {
    condition     = alltrue([for protocol in var.vpn_client_protocols : contains(["SSTP", "IkeV2", "OpenVPN"], protocol)])
    error_message = "VPN client protocols must be SSTP, IkeV2, or OpenVPN."
  }
}

# Azure AD Configuration
variable "aad_tenant_id" {
  type        = string
  description = "Azure AD Tenant ID"
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.aad_tenant_id))
    error_message = "The aad_tenant_id must be a valid GUID format (e.g., 12345678-1234-1234-1234-123456789012)."
  }
}

variable "aad_audience" {
  type        = string
  description = "Azure AD Application ID for VPN authentication"
  default     = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # Azure VPN Client App ID
}

variable "aad_issuer" {
  type        = string
  description = "Azure AD Issuer URL"
}

# Certificate Authentication (optional)
variable "root_certificate_data" {
  type        = string
  description = "Root certificate data for certificate-based authentication"
  default     = null
  sensitive   = true
}

variable "hub_vnet_address_space" {
  type        = string
  description = "Hub VNet address space for connection instructions"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}