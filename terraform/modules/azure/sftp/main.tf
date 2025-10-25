# EM SFTP Module
# Creates Azure Storage Account with SFTP enabled, NAT Gateway, Private Endpoint,
# NSG rules, Azure Firewall integration, and Automation Account for data movement

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# SFTP Storage Account with hierarchical namespace and GRS replication
resource "azurerm_storage_account" "main" {
  count = var.create_sftp_storage ? 1 : 0

  name                     = var.storage_account_name
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = var.account_kind
  access_tier              = var.account_kind == "BlockBlobStorage" ? null : var.access_tier

  # Enable SFTP with hierarchical namespace
  is_hns_enabled             = true
  sftp_enabled               = true
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  # Disable public access - use private endpoint only
  public_network_access_enabled   = var.public_network_access_enabled
  allow_nested_items_to_be_public = false

  # Network rules - default deny with specific allow rules
  network_rules {
    default_action             = var.network_default_action
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_addresses
  }

  # Blob properties for lifecycle management
  blob_properties {
    versioning_enabled  = var.enable_versioning
    change_feed_enabled = var.enable_change_feed

    delete_retention_policy {
      days = var.blob_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_delete_retention_days
    }
  }

  # Managed identity for secure access (added after initial creation to avoid BadRequest)
  dynamic "identity" {
    for_each = var.enable_managed_identity ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  tags = var.tags
}

# SFTP Containers (incoming, outgoing, archive)
resource "azurerm_storage_container" "containers" {
  for_each = var.create_sftp_storage ? var.containers : {}

  name                  = each.key
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

# Storage Account Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "sftp_diag" {
  count = var.create_sftp_storage && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${var.storage_account_name}-diag"
  target_resource_id         = azurerm_storage_account.main[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# NAT Gateway Public IP
resource "azurerm_public_ip" "natgw_pip" {
  count = var.create_nat_gateway ? 1 : 0

  name                = var.nat_gateway_pip_name
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones

  tags = var.tags
}

# NAT Gateway
resource "azurerm_nat_gateway" "natgw" {
  count = var.create_nat_gateway ? 1 : 0

  name                    = var.nat_gateway_name
  location                = var.location
  resource_group_name     = var.rg_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.nat_idle_timeout
  zones                   = var.availability_zones

  tags = var.tags
}

# Associate Public IP with NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  count = var.create_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.natgw[0].id
  public_ip_address_id = azurerm_public_ip.natgw_pip[0].id
}

# Associate NAT Gateway with Subnet
resource "azurerm_subnet_nat_gateway_association" "natgw_subnet_assoc" {
  count = var.create_nat_gateway ? 1 : 0

  subnet_id      = var.sftp_subnet_id
  nat_gateway_id = azurerm_nat_gateway.natgw[0].id
}

# Private Endpoint for SFTP Storage
resource "azurerm_private_endpoint" "sftp_pe" {
  count = var.create_private_endpoint ? 1 : 0

  name                = var.private_endpoint_name
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.sftp_subnet_id

  private_service_connection {
    name                           = "${var.private_endpoint_name}-psc"
    private_connection_resource_id = azurerm_storage_account.main[0].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = var.tags
}

# Private DNS Zone for SFTP Storage
resource "azurerm_private_dns_zone" "blob" {
  count = var.create_private_dns_zone ? 1 : 0

  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.rg_name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "blob_vnet_link" {
  count = var.create_private_dns_zone ? 1 : 0

  name                  = "${var.vnet_name}-blob-dns-link"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.blob[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Private DNS A Record for SFTP Private Endpoint
resource "azurerm_private_dns_a_record" "sftp_pe_dns" {
  count = var.create_private_endpoint && var.create_private_dns_zone ? 1 : 0

  name                = var.storage_account_name
  zone_name           = azurerm_private_dns_zone.blob[0].name
  resource_group_name = var.rg_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sftp_pe[0].private_service_connection[0].private_ip_address]

  tags = var.tags
}

# Network Security Group for SFTP Subnet
resource "azurerm_network_security_group" "sftp_nsg" {
  count = var.create_sftp_nsg ? 1 : 0

  name                = "${var.subnet_name}-NSG"
  location            = var.location
  resource_group_name = var.rg_name

  tags = var.tags
}

# NSG Rule: Allow SFTP inbound from allowed IP ranges (only if IPs are specified)
resource "azurerm_network_security_rule" "allow_sftp_inbound" {
  count = var.create_sftp_nsg && length(var.sftp_allowed_source_ips) > 0 ? 1 : 0

  name                        = "AllowSFTPInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.sftp_allowed_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.sftp_nsg[0].name
}

# NSG Rule: Allow HTTPS for storage management (only if IPs are specified)
resource "azurerm_network_security_rule" "allow_https_inbound" {
  count = var.create_sftp_nsg && length(var.sftp_allowed_source_ips) > 0 ? 1 : 0

  name                        = "AllowHTTPSInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.sftp_allowed_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.sftp_nsg[0].name
}

# NSG Rule: Allow private network access
resource "azurerm_network_security_rule" "allow_private_inbound" {
  count = var.create_sftp_nsg ? 1 : 0

  name                        = "AllowPrivateInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.sftp_nsg[0].name
}

# NSG Rule: Allow VNet traffic
resource "azurerm_network_security_rule" "allow_vnet_inbound" {
  count = var.create_sftp_nsg ? 1 : 0

  name                        = "AllowVnetInbound"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.sftp_nsg[0].name
}

# NSG Rule: Deny all other inbound
resource "azurerm_network_security_rule" "deny_all_inbound" {
  count = var.create_sftp_nsg ? 1 : 0

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
  network_security_group_name = azurerm_network_security_group.sftp_nsg[0].name
}

# NSG Rule: Allow all outbound
resource "azurerm_network_security_rule" "allow_all_outbound" {
  count = var.create_sftp_nsg ? 1 : 0

  name                        = "AllowAllOutbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.sftp_nsg[0].name
}

# Associate NSG with SFTP Subnet
resource "azurerm_subnet_network_security_group_association" "sftp_nsg_assoc" {
  count = var.create_sftp_nsg ? 1 : 0

  subnet_id                 = var.sftp_subnet_id
  network_security_group_id = azurerm_network_security_group.sftp_nsg[0].id
}

# Azure Firewall Subnet (AzureFirewallSubnet)
# Note: This is typically created in the networking module, but included here for reference
# Firewall Public IP
resource "azurerm_public_ip" "firewall_pip" {
  count = var.create_firewall ? 1 : 0

  name                = var.firewall_pip_name
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones

  tags = var.tags
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  count = var.create_firewall ? 1 : 0

  name                = var.firewall_name
  location            = var.location
  resource_group_name = var.rg_name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = var.firewall_policy_id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.firewall_pip[0].id
  }

  tags = var.tags
}

# Firewall Network Rule Collection for SFTP
resource "azurerm_firewall_network_rule_collection" "sftp_rules" {
  count = var.create_firewall && var.firewall_policy_id == null ? 1 : 0

  name                = "sftp-network-rules"
  azure_firewall_name = azurerm_firewall.main[0].name
  resource_group_name = var.rg_name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-sftp-inbound"
    source_addresses      = var.sftp_allowed_source_ips
    destination_ports     = ["22"]
    destination_addresses = [azurerm_public_ip.firewall_pip[0].ip_address]
    protocols             = ["TCP"]
  }

  rule {
    name                  = "allow-https-inbound"
    source_addresses      = var.sftp_allowed_source_ips
    destination_ports     = ["443"]
    destination_addresses = [azurerm_public_ip.firewall_pip[0].ip_address]
    protocols             = ["TCP"]
  }
}

# Azure Automation Account for SFTP data movement
resource "azurerm_automation_account" "main" {
  count = var.create_automation_account ? 1 : 0

  name                = var.automation_account_name
  location            = var.location
  resource_group_name = var.rg_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Automation Runbook for SFTP to SMB data sync
resource "azurerm_automation_runbook" "sftp_sync" {
  count = var.create_automation_account ? 1 : 0

  name                    = "${var.automation_account_name}-sftp-sync"
  location                = var.location
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.main[0].name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"

  content = var.sftp_sync_runbook_content != "" ? var.sftp_sync_runbook_content : <<-RUNBOOK
    param(
      [string]$StorageAccountName,
      [string]$ContainerName,
      [string]$DestinationPath
    )

    # Connect using managed identity
    Connect-AzAccount -Identity

    # Get storage context
    $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

    # List and copy files
    $blobs = Get-AzStorageBlob -Container $ContainerName -Context $ctx

    foreach ($blob in $blobs) {
      $destFile = Join-Path $DestinationPath $blob.Name
      Get-AzStorageBlobContent -Blob $blob.Name -Container $ContainerName -Destination $destFile -Context $ctx -Force
      Write-Output "Copied: $($blob.Name)"
    }
  RUNBOOK

  tags = var.tags
}

# Automation Schedule for periodic sync
resource "azurerm_automation_schedule" "sftp_sync_schedule" {
  count = var.create_automation_account && var.enable_automation_schedule ? 1 : 0

  name                    = "${var.automation_account_name}-schedule"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.main[0].name
  frequency               = var.automation_schedule_frequency
  interval                = var.automation_schedule_interval
  timezone                = var.automation_schedule_timezone
  description             = "SFTP to SMB data sync schedule"
}

# Link Schedule to Runbook
resource "azurerm_automation_job_schedule" "sftp_sync_job" {
  count = var.create_automation_account && var.enable_automation_schedule ? 1 : 0

  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.main[0].name
  schedule_name           = azurerm_automation_schedule.sftp_sync_schedule[0].name
  runbook_name            = azurerm_automation_runbook.sftp_sync[0].name

  parameters = {
    storageaccountname = var.storage_account_name
    containername      = var.automation_source_container
    destinationpath    = var.automation_destination_path
  }
}

# Private Endpoint for Automation Account
resource "azurerm_private_endpoint" "automation_pe" {
  count = var.create_automation_account && var.create_automation_private_endpoint ? 1 : 0

  name                = "${var.automation_account_name}-PE1"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.sftp_subnet_id

  private_service_connection {
    name                           = "${var.automation_account_name}-psc"
    private_connection_resource_id = azurerm_automation_account.main[0].id
    subresource_names              = ["DSCAndHybridWorker"]
    is_manual_connection           = false
  }

  tags = var.tags
}

# Private DNS Zone for Automation Account
resource "azurerm_private_dns_zone" "automation" {
  count = var.create_automation_account && var.create_automation_private_dns_zone ? 1 : 0

  name                = "privatelink.azure-automation.net"
  resource_group_name = var.rg_name

  tags = var.tags
}

# Link Automation Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "automation_vnet_link" {
  count = var.create_automation_account && var.create_automation_private_dns_zone ? 1 : 0

  name                  = "${var.vnet_name}-automation-dns-link"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.automation[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Private DNS A Record for Automation Private Endpoint
resource "azurerm_private_dns_a_record" "automation_pe_dns" {
  count = var.create_automation_account && var.create_automation_private_endpoint && var.create_automation_private_dns_zone ? 1 : 0

  name                = lower(var.automation_account_name)
  zone_name           = azurerm_private_dns_zone.automation[0].name
  resource_group_name = var.rg_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.automation_pe[0].private_service_connection[0].private_ip_address]

  tags = var.tags
}
