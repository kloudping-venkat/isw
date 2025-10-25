# EM SFTP Module

Terraform module for deploying Azure SFTP infrastructure following production patterns and security best practices.

## Features

This module creates a comprehensive SFTP solution with:

### Storage
- **Azure Storage Account** with SFTP enabled
- Hierarchical namespace for Data Lake Gen2
- GRS replication for geo-redundancy
- Blob versioning and change feed
- Soft delete and retention policies
- Private network access with firewall rules
- Managed identity for secure access

### Networking
- **Private Endpoint** for secure storage access
- **Private DNS Zone** for name resolution
- **NAT Gateway** for controlled outbound connectivity
- **Network Security Group** with granular rules:
  - SFTP (port 22) from allowed IPs
  - HTTPS (port 443) for management
  - VNet and private network access
  - Default deny for unauthorized traffic

### Security
- **Azure Firewall** (optional) for centralized traffic control
- TLS 1.2 minimum enforcement
- No public blob access
- Network isolation via private endpoints
- NSG rules following production patterns

### Monitoring
- **Diagnostic Settings** for storage account
- Integration with Log Analytics workspace
- Metrics and logs for compliance

### Automation
- **Azure Automation Account** (optional) for SFTP→SMB data movement
- Scheduled runbooks for periodic sync
- Managed identity for secure automation
- Customizable PowerShell runbook content

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Virtual Network                        │
│                                                           │
│  ┌─────────────────────┐    ┌──────────────────────┐   │
│  │  SFTP Subnet        │    │  AzureFirewallSubnet │   │
│  │  + NSG Rules        │    │  (optional)          │   │
│  │  + Private Endpoint │    │  + Firewall          │   │
│  │  + NAT Gateway      │    │  + Public IP         │   │
│  └──────────┬──────────┘    └──────────────────────┘   │
│             │                                            │
└─────────────┼────────────────────────────────────────────┘
              │
              │ Private Link
              ▼
   ┌──────────────────────┐
   │  Storage Account     │
   │  + SFTP Enabled      │
   │  + Blob Containers   │
   │    - incoming        │
   │    - outgoing        │
   │    - archive         │
   │  + Diagnostics       │
   └──────────────────────┘
              │
              │ RBAC
              ▼
   ┌──────────────────────┐
   │ Automation Account   │
   │ + Runbook (sync)     │
   │ + Schedule           │
   │ + Managed Identity   │
   └──────────────────────┘
```

## Usage

### Basic Example

```hcl
module "sftp" {
  source = "./modules/em/sftp"

  # Required variables
  rg_name              = "US1-BofA-P-RG"
  location             = "eastus"
  storage_account_name = "usbofapsftp"

  # Networking
  sftp_subnet_id = module.networking.subnet_ids["SFTP-SUBNET"]
  vnet_id        = module.networking.vnet_id
  vnet_name      = "US1-BofA-P-VNET"

  # Security
  sftp_allowed_source_ips = [
    "203.0.113.0/24",  # BofA office network
    "198.51.100.0/24"  # Partner network
  ]

  # Storage containers
  containers = {
    incoming = {}
    outgoing = {}
    archive  = {}
  }

  tags = {
    Environment = "Production"
    Project     = "BofA-SFTP"
    ManagedBy   = "Terraform"
  }
}
```

### Advanced Example with Firewall and Automation

```hcl
module "sftp" {
  source = "./modules/em/sftp"

  # Required variables
  rg_name              = "US1-BofA-P-RG"
  location             = "eastus"
  storage_account_name = "usbofapsftp"

  # Networking
  sftp_subnet_id     = module.networking.subnet_ids["SFTP-SUBNET"]
  firewall_subnet_id = module.networking.subnet_ids["AzureFirewallSubnet"]
  vnet_id            = module.networking.vnet_id
  vnet_name          = "US1-BofA-P-VNET"
  subnet_name        = "SFTP-SUBNET"

  # Storage configuration
  replication_type              = "GRS"
  enable_versioning             = true
  blob_delete_retention_days    = 30
  container_delete_retention_days = 30

  # Security
  public_network_access_enabled = false
  network_default_action        = "Deny"
  sftp_allowed_source_ips = [
    "203.0.113.0/24",
    "198.51.100.0/24"
  ]

  # Firewall
  create_firewall      = true
  firewall_name        = "US1-BofA-P-FW01"
  firewall_pip_name    = "US1-BofA-P-FW01-PIP"
  firewall_sku_tier    = "Standard"

  # NAT Gateway
  create_nat_gateway   = true
  nat_gateway_name     = "US1-BofA-P-SFTP-NATGW"
  nat_gateway_pip_name = "US1-BofA-P-SFTP-NATGW-PIP"

  # Monitoring
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  # Automation
  create_automation_account    = true
  automation_account_name      = "US1-BofA-P-SFTP-AA"
  enable_automation_schedule   = true
  automation_schedule_frequency = "Hour"
  automation_schedule_interval = 4
  automation_source_container  = "incoming"
  automation_destination_path  = "\\\\fileserver\\sftp\\incoming"

  # Containers
  containers = {
    incoming = {}
    outgoing = {}
    archive  = {}
    quarantine = {}
  }

  tags = {
    Environment = "Production"
    Project     = "BofA-SFTP"
    Compliance  = "SOX"
    ManagedBy   = "Terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.0 |

## Resources Created

### Always Created (when enabled)
- `azurerm_storage_account.main` - SFTP-enabled storage account
- `azurerm_storage_container.containers` - Blob containers (incoming, outgoing, archive)

### Conditional Resources
- `azurerm_private_endpoint.sftp_pe` - Private endpoint (if `create_private_endpoint = true`)
- `azurerm_private_dns_zone.blob` - Private DNS zone (if `create_private_dns_zone = true`)
- `azurerm_nat_gateway.natgw` - NAT Gateway (if `create_nat_gateway = true`)
- `azurerm_network_security_group.sftp_nsg` - NSG (if `create_sftp_nsg = true`)
- `azurerm_firewall.main` - Azure Firewall (if `create_firewall = true`)
- `azurerm_automation_account.main` - Automation Account (if `create_automation_account = true`)
- `azurerm_monitor_diagnostic_setting.sftp_diag` - Diagnostics (if `log_analytics_workspace_id` provided)

## Inputs

### Required Variables

| Name | Type | Description |
|------|------|-------------|
| rg_name | string | Resource group name |
| location | string | Azure region |
| storage_account_name | string | Storage account name (3-24 lowercase alphanumeric) |

### Storage Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| create_sftp_storage | bool | true | Create SFTP storage account |
| account_tier | string | "Standard" | Storage account tier |
| replication_type | string | "GRS" | Replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS) |
| access_tier | string | "Hot" | Access tier (Hot or Cool) |
| enable_versioning | bool | true | Enable blob versioning |
| enable_change_feed | bool | true | Enable blob change feed |
| blob_delete_retention_days | number | 30 | Blob soft delete retention days |
| container_delete_retention_days | number | 30 | Container soft delete retention days |
| containers | map(any) | {incoming, outgoing, archive} | Containers to create |

### Networking

| Name | Type | Default | Description |
|------|------|---------|-------------|
| sftp_subnet_id | string | null | SFTP subnet ID for private endpoint |
| subnet_name | string | "SFTP-SUBNET" | Subnet name for NSG naming |
| vnet_id | string | null | VNet ID for private DNS zone link |
| vnet_name | string | "" | VNet name for DNS zone link naming |
| public_network_access_enabled | bool | false | Enable public network access |
| network_default_action | string | "Deny" | Default network action |
| allowed_subnet_ids | list(string) | [] | Allowed subnet IDs |
| allowed_ip_addresses | list(string) | [] | Allowed IP addresses (CIDR) |

### Security

| Name | Type | Default | Description |
|------|------|---------|-------------|
| create_sftp_nsg | bool | true | Create dedicated NSG for SFTP subnet |
| sftp_allowed_source_ips | list(string) | [] | Allowed source IPs for SFTP (CIDR) |
| create_private_endpoint | bool | true | Create private endpoint |
| create_private_dns_zone | bool | true | Create private DNS zone |

### Firewall

| Name | Type | Default | Description |
|------|------|---------|-------------|
| create_firewall | bool | false | Create Azure Firewall |
| firewall_name | string | "" | Firewall name |
| firewall_pip_name | string | "" | Firewall public IP name |
| firewall_sku_tier | string | "Standard" | Firewall SKU (Standard or Premium) |
| firewall_subnet_id | string | null | AzureFirewallSubnet ID |

### Automation

| Name | Type | Default | Description |
|------|------|---------|-------------|
| create_automation_account | bool | false | Create Automation Account |
| automation_account_name | string | "" | Automation Account name |
| enable_automation_schedule | bool | false | Enable automation schedule |
| automation_schedule_frequency | string | "Hour" | Schedule frequency |
| automation_schedule_interval | number | 1 | Schedule interval |
| automation_source_container | string | "incoming" | Source container for sync |
| automation_destination_path | string | "" | Destination SMB path |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| storage_account_id | Storage account resource ID |
| storage_account_name | Storage account name |
| storage_account_primary_blob_endpoint | Primary blob endpoint URL |
| private_endpoint_ip_address | Private endpoint IP |
| nat_gateway_public_ip | NAT Gateway public IP |
| firewall_public_ip | Firewall public IP (if enabled) |
| automation_account_id | Automation Account ID (if enabled) |

See [outputs.tf](./outputs.tf) for complete list of outputs.

## Production Patterns Implemented

This module follows production patterns from existing EM modules:

1. **File Headers**: Clear module description and purpose
2. **Data Sources**: Uses `azurerm_client_config` for current Azure context
3. **Resource Naming**: Uses `.main` for primary resources, descriptive names
4. **NSG Rules**:
   - Priority ranges (100s for inbound, 200s for outbound)
   - Specific rules before broad rules
   - Explicit deny-all at priority 4096
   - Clear rule names and descriptions
5. **Security by Default**:
   - Private endpoint by default
   - Public access disabled
   - Network default action: Deny
   - TLS 1.2 minimum
6. **Monitoring**: Diagnostic settings integration
7. **Managed Identities**: For secure service-to-service auth
8. **Tags**: Consistent tagging across all resources

## Post-Deployment Configuration

After deploying this module, you'll need to:

1. **Configure SFTP Users**:
   ```bash
   # Create local user for SFTP
   az storage account local-user create \
     --account-name <storage-account-name> \
     --name <username> \
     --home-directory <container-name> \
     --permission-scope permissions=rcwdl service=blob resource-name=<container-name> \
     --has-ssh-password true

   # Or use SSH keys for authentication
   az storage account local-user create \
     --account-name <storage-account-name> \
     --name <username> \
     --home-directory <container-name> \
     --permission-scope permissions=rcwdl service=blob resource-name=<container-name> \
     --ssh-authorized-key key="<ssh-public-key>"
   ```

2. **Test SFTP Connection**:
   ```bash
   sftp <username>@<storage-account-name>.blob.core.windows.net
   ```

3. **Configure Firewall Rules** (if using Azure Firewall):
   - Add DNAT rules for SFTP traffic
   - Configure application rules as needed

4. **Set Up Automation Runbook** (if using automation):
   - Import required PowerShell modules
   - Configure SMB share credentials in Key Vault
   - Test runbook execution manually

## License

Proprietary - Internal Use Only
