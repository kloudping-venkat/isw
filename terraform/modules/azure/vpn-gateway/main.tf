# VPN Gateway Module - Point-to-Site with Azure AD Authentication
# Deploys VPN Gateway in GatewaySubnet with Azure AD authentication

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway_pip" {
  name                = "${var.gateway_name}-PIP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = can(regex("AZ$", var.gateway_sku)) ? var.availability_zones : null

  tags = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = var.gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = var.active_active
  enable_bgp    = var.enable_bgp
  sku           = var.gateway_sku
  generation    = var.gateway_generation

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  dynamic "ip_configuration" {
    for_each = var.active_active ? [1] : []
    content {
      name                          = "vnetGatewayConfig2"
      public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip_secondary[0].id
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = var.gateway_subnet_id
    }
  }

  vpn_client_configuration {
    address_space = var.vpn_client_address_space

    aad_tenant   = "https://login.microsoftonline.com/${var.aad_tenant_id}"
    aad_audience = var.aad_audience
    aad_issuer   = var.aad_issuer

    vpn_client_protocols = var.vpn_client_protocols
    vpn_auth_types       = ["AAD"]
  }

  tags = var.tags

  depends_on = [azurerm_public_ip.vpn_gateway_pip]
}

# Secondary Public IP for Active-Active configuration
resource "azurerm_public_ip" "vpn_gateway_pip_secondary" {
  count = var.active_active ? 1 : 0

  name                = "${var.gateway_name}-PIP-2"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = can(regex("AZ$", var.gateway_sku)) ? var.availability_zones : null

  tags = var.tags
}

# Generate VPN client configuration
data "azurerm_virtual_network_gateway" "vpn_gateway_config" {
  name                = azurerm_virtual_network_gateway.vpn_gateway.name
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_virtual_network_gateway.vpn_gateway]
}

# Store VPN client configuration in Key Vault
resource "azurerm_key_vault_secret" "vpn_client_config" {
  name = "${var.gateway_name}-client-config"
  value = jsonencode({
    gateway_name      = azurerm_virtual_network_gateway.vpn_gateway.name
    gateway_id        = azurerm_virtual_network_gateway.vpn_gateway.id
    public_ip_address = azurerm_public_ip.vpn_gateway_pip.ip_address
    vpn_client_config = {
      address_space        = var.vpn_client_address_space
      aad_tenant_id        = var.aad_tenant_id
      aad_audience         = var.aad_audience
      aad_issuer           = var.aad_issuer
      vpn_client_protocols = var.vpn_client_protocols
      download_url         = "https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/virtualNetworkGateways/${azurerm_virtual_network_gateway.vpn_gateway.name}/generatevpnclientpackage?api-version=2021-02-01"
    }
    connection_instructions = {
      step1 = "Download Azure VPN Client from Microsoft Store"
      step2 = "Import the VPN profile using the download URL above"
      step3 = "Connect using your Azure AD credentials"
      step4 = "Verify connection to hub network: ${var.hub_vnet_address_space}"
    }
  })
  key_vault_id = var.key_vault_id

  content_type = "application/json"

  tags = var.tags

  depends_on = [azurerm_virtual_network_gateway.vpn_gateway]
}

# Store VPN Gateway Certificate (if using certificate auth)
resource "azurerm_key_vault_secret" "vpn_gateway_certificate" {
  count = var.root_certificate_data != null ? 1 : 0

  name         = "${var.gateway_name}-root-certificate"
  value        = var.root_certificate_data
  key_vault_id = var.key_vault_id

  content_type = "application/x-pkcs12"

  tags = var.tags
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}