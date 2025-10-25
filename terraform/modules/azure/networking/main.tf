# Azure Virtual Network using official Azure module
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "~> 4.0"

  use_for_each        = true
  resource_group_name = var.rg_name
  vnet_location       = var.location
  vnet_name           = var.vnet_name
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers

  # Create subnets using the module with proper naming
  subnet_prefixes = [for subnet in var.subnets : subnet.address_prefix]
  subnet_names    = [for name, subnet in var.subnets : name == "GatewaySubnet" || name == "AzureBastionSubnet" ? name : "${replace(var.vnet_name, "-VNET", "")}-${name}"]

  # Enable service endpoints per subnet using correct names
  subnet_service_endpoints = {
    for name, subnet in var.subnets : (name == "GatewaySubnet" || name == "AzureBastionSubnet" ? name : "${replace(var.vnet_name, "-VNET", "")}-${name}") => lookup(subnet, "service_endpoints", [])
  }

  tags = var.tags
}

# Custom Network Security Groups for advanced rules (not created by module)
# Exclude GatewaySubnet as Azure doesn't allow NSGs on Gateway subnets
resource "azurerm_network_security_group" "subnet_nsg" {
  for_each = { for k, v in var.subnets : k => v if k != "GatewaySubnet" }

  name                = "${replace(var.vnet_name, "-VNET", "")}-${each.key}-NSG"
  location            = var.location
  resource_group_name = var.rg_name

  tags = var.tags
}

# Allow ALL inbound traffic from private networks (wide open for connectivity)
# Exclude GatewaySubnet as it cannot have NSG rules
# Exclude AG-SUBNET as it has specific Application Gateway rules
resource "azurerm_network_security_rule" "allow_private_inbound" {
  for_each = { for k, v in var.subnets : k => v if k != "GatewaySubnet" && k != "AzureBastionSubnet" && k != "AG-SUBNET" }

  name                        = "AllowPrivateInBound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg[each.key].name
}

# Allow VirtualNetwork inbound traffic separately (system tag)
# Exclude AG-SUBNET as it has specific Application Gateway rules
resource "azurerm_network_security_rule" "allow_vnet_inbound" {
  for_each = { for k, v in var.subnets : k => v if k != "GatewaySubnet" && k != "AzureBastionSubnet" && k != "AG-SUBNET" }

  name                        = "AllowVnetInBound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg[each.key].name
}

# Allow ALL outbound traffic (wide open for connectivity)
# Exclude GatewaySubnet, AzureBastionSubnet, and AG-SUBNET (all have specific rules)
resource "azurerm_network_security_rule" "allow_all_outbound" {
  for_each = { for k, v in var.subnets : k => v if k != "GatewaySubnet" && k != "AzureBastionSubnet" && k != "AG-SUBNET" }

  name                        = "AllowAllOutBound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg[each.key].name
}

# AKS-specific NSG rules for LOGI-SUBNET
resource "azurerm_network_security_rule" "aks_api_server_inbound" {
  count = contains(keys(var.subnets), "LOGI-SUBNET") ? 1 : 0

  name                        = "AllowAKSApiServerInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

resource "azurerm_network_security_rule" "aks_kubelet_inbound" {
  count = contains(keys(var.subnets), "LOGI-SUBNET") ? 1 : 0

  name                        = "AllowKubeletInbound"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["10250", "10255"]
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

# Allow AKS to connect to databases and applications
resource "azurerm_network_security_rule" "aks_database_outbound" {
  count = contains(keys(var.subnets), "LOGI-SUBNET") ? 1 : 0

  name                         = "AllowDatabaseConnectionsOutbound"
  priority                     = 210
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_ranges      = ["1433", "1521", "5432", "3306"]
  source_address_prefix        = "*"
  destination_address_prefixes = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  resource_group_name          = var.rg_name
  network_security_group_name  = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

# Allow Logi Symphony ingress traffic from VPN clients
resource "azurerm_network_security_rule" "logi_ingress_from_vpn" {
  count = contains(keys(var.subnets), "LOGI-SUBNET") ? 1 : 0

  name                        = "AllowLogiIngressFromVPN"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "9090"]
  source_address_prefixes     = ["172.16.0.0/24", "10.0.0.0/8"] # VPN client range + private networks
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

# Allow APP, WEB, and DB subnets to connect to Logi Symphony services
resource "azurerm_network_security_rule" "allow_app_to_logi" {
  count = contains(keys(var.subnets), "APP-SUBNET") && contains(keys(var.subnets), "LOGI-SUBNET") ? 1 : 0

  name                        = "AllowAppToLogiServices"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "9090"]
  source_address_prefix       = lookup(var.subnets["APP-SUBNET"], "address_prefix", "")
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

resource "azurerm_network_security_rule" "allow_web_to_logi" {
  count = contains(keys(var.subnets), "WEB-SUBNET") && contains(keys(var.subnets), "LOGI-SUBNET") ? 1 : 0

  name                        = "AllowWebToLogiServices"
  priority                    = 160
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "9090"]
  source_address_prefix       = lookup(var.subnets["WEB-SUBNET"], "address_prefix", "")
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

# Allow Logi to connect to database services
resource "azurerm_network_security_rule" "allow_logi_to_db_outbound" {
  count = contains(keys(var.subnets), "LOGI-SUBNET") && contains(keys(var.subnets), "DB-SUBNET") ? 1 : 0

  name                        = "AllowLogiToDbOutbound"
  priority                    = 220
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["1521", "5432", "1433"]
  source_address_prefix       = "*"
  destination_address_prefix  = lookup(var.subnets["DB-SUBNET"], "address_prefix", "")
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["LOGI-SUBNET"].name
}

# Allow DB subnet to accept connections from Logi
resource "azurerm_network_security_rule" "allow_logi_to_db_inbound" {
  count = contains(keys(var.subnets), "LOGI-SUBNET") && contains(keys(var.subnets), "DB-SUBNET") ? 1 : 0

  name                        = "AllowLogiToDbInbound"
  priority                    = 170
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["1521", "5432", "1433"]
  source_address_prefix       = lookup(var.subnets["LOGI-SUBNET"], "address_prefix", "")
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["DB-SUBNET"].name
}

# Azure Bastion specific NSG rules
resource "azurerm_network_security_rule" "bastion_allow_https_inbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowHttpsInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_gateway_manager_inbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowGatewayManagerInbound"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_load_balancer_inbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowAzureLoadBalancerInbound"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

# Deny all other inbound traffic to Bastion subnet (required for compliance)
resource "azurerm_network_security_rule" "bastion_deny_all_inbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_bastion_communication" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowBastionCommunication"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_ssh_rdp_outbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowSshRdpOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389"]
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_azure_cloud_outbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowAzureCloudOutbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_bastion_communication_outbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowBastionCommunicationOutbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

resource "azurerm_network_security_rule" "bastion_allow_get_session_information" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "AllowGetSessionInformation"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

# Deny all other outbound traffic from Bastion subnet (required for compliance)
resource "azurerm_network_security_rule" "bastion_deny_all_outbound" {
  count = contains(keys(var.subnets), "AzureBastionSubnet") ? 1 : 0

  name                        = "DenyAllOutbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AzureBastionSubnet"].name
}

# Application Gateway specific NSG rules
# Required for Application Gateway v2 SKU
resource "azurerm_network_security_rule" "appgw_allow_gateway_manager" {
  count = contains(keys(var.subnets), "AG-SUBNET") ? 1 : 0

  name                        = "AllowGatewayManagerInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AG-SUBNET"].name
}

resource "azurerm_network_security_rule" "appgw_allow_internet_inbound" {
  count = contains(keys(var.subnets), "AG-SUBNET") ? 1 : 0

  name                        = "AllowInternetInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AG-SUBNET"].name
}

resource "azurerm_network_security_rule" "appgw_allow_azureloadbalancer" {
  count = contains(keys(var.subnets), "AG-SUBNET") ? 1 : 0

  name                        = "AllowAzureLoadBalancerInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg["AG-SUBNET"].name
}

# Associate custom NSGs with subnets created by the module
# Exclude GatewaySubnet as Azure doesn't allow NSGs on Gateway subnets
# Temporarily exclude LOGI-SUBNET for AKS connectivity troubleshooting
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  for_each = { for k, v in var.subnets : k => v if k != "GatewaySubnet" && k != "LOGI-SUBNET" }

  subnet_id                 = module.vnet.vnet_subnets_name_id[each.key == "AzureBastionSubnet" ? each.key : "${replace(var.vnet_name, "-VNET", "")}-${each.key}"]
  network_security_group_id = azurerm_network_security_group.subnet_nsg[each.key].id
}