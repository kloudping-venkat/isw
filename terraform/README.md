# EM NextGen Infrastructure as Code (IaC)

## Overview

This repository contains Terraform Infrastructure as Code (IaC) for deploying Azure networking infrastructure following a **Hub-Spoke Architecture** pattern. The infrastructure is designed to be flexible, scalable, and follows enterprise-grade naming conventions.

## Architecture

### Hub-Spoke Network Design

The infrastructure implements a centralized hub-spoke network topology:

- **Hub VNet**: Contains shared services and gateway connectivity
- **Spoke VNet**: Contains application workloads and data services
- **VNet Peering**: Bidirectional connectivity with gateway transit

### Network Segmentation

#### Hub VNet (10.223.30.0/24)
- **GatewaySubnet** (10.223.30.0/26) - VPN Gateway and connectivity
- **AzureBastionSubnet** (10.223.30.64/26) - Secure remote access
- **Shared Services Subnet** (10.223.30.128/26) - DNS, domain controllers, shared key vault
- **Management Subnet** (10.223.30.192/26) - Jump boxes, monitoring, management tools

#### Spoke VNet (10.223.31.0/22)
- **Web Subnet** (10.223.31.0/24) - Application Gateway, web servers, load balancers
- **App Subnet** (10.223.32.0/24) - Application servers, AKS, container registry
- **Database Subnet** (10.223.33.0/24) - Oracle, SQL, PostgreSQL, MySQL databases
- **DevOps Subnet** (10.223.34.0/24) - Azure DevOps agents, build servers, artifacts

## Naming Convention

### Standard Format

All resources follow a consistent naming convention:

```
{LOCATION_CODE}-{CLIENT}-{ENVIRONMENT}-{RESOURCE_TYPE}-{DESCRIPTOR}
```

### Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `location_code` | Geographic location identifier | US1, EU1, AP1 | US1 |
| `client` | Client organization name | BOFA, CHASE, WELLS | BOFA |
| `environment` | Environment type | CS, PROD, DEV, TEST | CS |

### Examples

#### Resource Groups
- Hub: `US1-BOFA-CS-HUB-RG`
- Spoke: `US1-BOFA-CS-SPOKE-RG`

#### Virtual Networks
- Hub: `US1-BOFA-CS-HUB-VNET`
- Spoke: `US1-BOFA-CS-SPOKE-VNET`

#### Subnets
- Web Tier: `US1-BOFA-CS-SPOKE-WEB-SUBNET`
- App Tier: `US1-BOFA-CS-SPOKE-APP-SUBNET`
- Database: `US1-BOFA-CS-SPOKE-DB-SUBNET`
- DevOps: `US1-BOFA-CS-SPOKE-ADO-SUBNET`

#### Network Security Groups
- Web NSG: `US1-BOFA-CS-SPOKE-WEB-SUBNET-NSG`
- App NSG: `US1-BOFA-CS-SPOKE-APP-SUBNET-NSG`
- Database NSG: `US1-BOFA-CS-SPOKE-DB-SUBNET-NSG`
- DevOps NSG: `US1-BOFA-CS-SPOKE-ADO-SUBNET-NSG`

#### VNet Peering
- Hub to Spoke: `US1-BOFA-CS-HUB-TO-SPOKE-PEERING`
- Spoke to Hub: `US1-BOFA-CS-SPOKE-TO-HUB-PEERING`

### Special Cases

#### Azure Required Names
Some Azure resources have naming requirements that cannot be customized:
- `GatewaySubnet` - Required name for VPN Gateway subnet
- `AzureBastionSubnet` - Required name for Azure Bastion subnet

## Variables Configuration

### Core Variables

```hcl
# Geographic and organizational identifiers
variable "location_code" {
  description = "Location code (e.g., US1, EU1, AP1)"
  type        = string
  default     = "US1"
}

variable "client" {
  description = "Client name (e.g., BOFA, CHASE, WELLS)"
  type        = string
  default     = "BOFA"
}

variable "environment" {
  description = "Environment name (e.g., CS, PROD, DEV, TEST)"
  type        = string
  default     = "CS"
}

# Azure region for resource deployment
variable "location" {
  description = "Azure region (e.g., East US, West Europe)"
  type        = string
}
```

### Network Variables

```hcl
# Hub VNet CIDR block
variable "hub_vnet_address_space" {
  description = "CIDR block for the HUB VNet"
  type        = string
  default     = "10.223.30.0/24"
}

# Spoke VNet CIDR block
variable "spoke_vnet_address_space" {
  description = "CIDR block for the SPOKE VNet"
  type        = string
  default     = "10.223.31.0/22"
}
```

## Service Endpoints

Each subnet is configured with appropriate service endpoints for secure connectivity:

### Hub Subnets
- **Shared Services**: Microsoft.Storage, Microsoft.KeyVault
- **Management**: Microsoft.Storage

### Spoke Subnets
- **Web**: Microsoft.Storage, Microsoft.KeyVault, Microsoft.Web
- **App**: Microsoft.Storage, Microsoft.KeyVault, Microsoft.Sql
- **Database**: Microsoft.Storage, Microsoft.KeyVault, Microsoft.Sql
- **DevOps**: Microsoft.Storage, Microsoft.KeyVault, Microsoft.ContainerRegistry

## Deployment Instructions

### Prerequisites

1. **Azure CLI** installed and configured
2. **Terraform** >= 1.0 installed
3. **Azure subscription** with appropriate permissions
4. **Service Principal** or **Managed Identity** for Terraform authentication

### Basic Deployment

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd EM.NextGen-IaC/terraform
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Create terraform.tfvars file**
   ```hcl
   location_code = "US1"
   client        = "BOFA"
   environment   = "CS"
   location      = "East US"
   ```

4. **Plan deployment**
   ```bash
   terraform plan
   ```

5. **Apply configuration**
   ```bash
   terraform apply
   ```

### Multi-Environment Deployment

For different environments, create separate `.tfvars` files:

#### Development Environment
```hcl
# dev.tfvars
location_code = "US1"
client        = "BOFA"
environment   = "DEV"
location      = "East US"
```

#### Production Environment
```hcl
# prod.tfvars
location_code = "US1"
client        = "BOFA"
environment   = "PROD"
location      = "East US"
```

#### Multi-Client Example
```hcl
# chase-cs.tfvars
location_code = "US1"
client        = "CHASE"
environment   = "CS"
location      = "Central US"
```

Deploy with specific variable files:
```bash
terraform apply -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
terraform apply -var-file="chase-cs.tfvars"
```

## Module Structure

```
terraform/
├── main.tf                 # Main configuration
├── variables.tf            # Variable definitions
├── modules/
│   ├── em/                 # EM parent module
│   │   ├── main.tf         # Orchestrates all EM submodules
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── rg/             # Resource Group submodule
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── networking/     # Networking submodule
│   │       ├── main.tf     # Uses official Azure VNet module
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md   # Networking-specific documentation
└── README.md              # This file
```

## Terraform Module Architecture

### 🏗️ EM Module Pattern

The infrastructure follows a **hierarchical module pattern** based on the EM (Enterprise Management) approach:

#### Parent Module (`modules/em/`)
- **Unified Infrastructure Module**: Acts as a single entry point for all EM-related resources
- **Orchestration Layer**: Coordinates multiple submodules (rg, networking, compute, storage, etc.)
- **Standardized Interface**: Provides consistent variable and output interfaces
- **Scalable Design**: Easy to add new resource types as submodules

#### Submodules
- **Resource Group (`modules/em/rg/`)**: Handles Azure resource group creation and management
- **Networking (`modules/em/networking/`)**: Uses official Azure VNet module for networking resources
- **Resource-Specific Design**: Each submodule handles a specific resource type
- **Official Azure Modules**: Leverages Microsoft's official Terraform modules where possible
- **Hybrid Approach**: Combines official modules with custom resources for specific requirements
- **Independent Development**: Each submodule can be developed and tested independently

### 🎯 Official Azure Modules Strategy

This infrastructure prioritizes using **official Azure Terraform modules** to ensure:

#### Benefits of Official Modules:
1. **Microsoft Support & Maintenance**
   - Regularly updated with latest Azure features
   - Microsoft-backed support and documentation
   - Community-tested and validated

2. **Best Practices Implementation**
   - Follows Azure Well-Architected Framework
   - Implements security and compliance standards
   - Handles Azure API changes automatically

3. **Reduced Development Time**
   - Pre-built, tested functionality
   - Less custom code to maintain
   - Faster feature adoption

4. **Enhanced Reliability**
   - Battle-tested across numerous deployments
   - Comprehensive error handling
   - Edge case management

#### Current Official Module Usage:

| Resource Type | Official Module | Version | Purpose |
|---------------|----------------|---------|---------|
| Virtual Network | `Azure/vnet/azurerm` | `~> 4.0` | VNet, subnets, service endpoints |
| Network Security Groups | Custom Resources | N/A | Organization-specific security rules |

#### Future Expansion Plan:
- **Compute**: `Azure/avm-res-compute-virtualmachine/azurerm`
- **Storage**: `Azure/avm-res-storage-storageaccount/azurerm`
- **Key Vault**: `Azure/avm-res-keyvault-vault/azurerm`
- **Container Registry**: `Azure/avm-res-containerregistry-registry/azurerm`

### 📦 Module Hierarchy Example

```hcl
# Main configuration - Single EM module call handles everything
module "hub_em" {
  source = "./modules/em"

  # EM module coordinates all submodules internally
  rg_name            = "US1-BOFA-CS-HUB-RG"
  location           = "East US"
  vnet_name          = "US1-BOFA-CS-HUB-VNET"
  vnet_address_space = ["10.223.30.0/24"]
  subnets            = local.hub_subnets
  tags               = var.tags
}

# EM module internally orchestrates:
# 1. Resource Group submodule
module "rg" {
  source = "./rg"
  # Creates the resource group
}

# 2. Networking submodule
module "networking" {
  source = "./networking"
  rg_name = module.rg.rg_name  # Uses RG from step 1
  # Uses official Azure VNet module + custom NSG resources
}
```

## Terraform Modules

The infrastructure is organized into a hierarchical module structure:

### EM Parent Module (`modules/em/`)
- **Unified Infrastructure Module** for all EM-related resources
- **Single Entry Point**: One module call handles complete infrastructure
- **Orchestration Layer**: Coordinates all submodules internally
- **Standardized Interface**: Consistent variables and outputs across environments
- **Dependency Management**: Handles inter-module dependencies automatically

### Resource Group Submodule (`modules/em/rg/`)
- **Foundation Layer**: Creates Azure resource groups
- **Naming Standards**: Follows organizational naming conventions
- **Lifecycle Management**: Handles resource group creation and tagging
- **Dependency Provider**: Provides RG name/ID to other submodules

### Networking Submodule (`modules/em/networking/`)
- **Official Azure VNet Module**: Uses `Azure/vnet/azurerm` for core networking
- **Hybrid Implementation**: Combines official modules with custom resources
- **Custom Security**: Implements organization-specific NSG rules
- **Service Endpoints**: Configured per subnet for secure Azure service connectivity
- **RG Integration**: Uses resource group created by RG submodule

### Module Benefits

1. **Consistency**: Standardized approach across all environments
2. **Maintainability**: Official modules reduce custom code maintenance
3. **Scalability**: Easy to add new resource types as submodules
4. **Reliability**: Leverages Microsoft-tested and community-validated modules
5. **Future-Proofing**: Automatic updates with new Azure features

## Security Features

### Network Security
- **Network Segmentation** through subnet isolation
- **Service Endpoints** for secure Azure service connectivity
- **VNet Peering** with controlled gateway transit
- **Private Connectivity** between hub and spoke networks

### Access Control
- **Azure Bastion** for secure VM access without public IPs
- **Gateway Transit** for centralized on-premises connectivity
- **Point-to-Site VPN** with Azure AD authentication
- **Subnet-level** network security group configurations

## VPN Gateway & Remote Access

### 🔐 Point-to-Site VPN with Azure AD Authentication

The infrastructure includes a secure Point-to-Site VPN gateway deployed in the hub network for remote access to Azure resources.

#### VPN Gateway Configuration
- **Location**: Hub VNet GatewaySubnet
- **Authentication**: Azure Active Directory (AAD)
- **Protocol**: OpenVPN
- **SKU**: VpnGw2 (Generation 2)
- **Client Address Pool**: `172.16.0.0/24`

#### Security Model
```
Azure AD Authentication → VPN Client → VPN Gateway → Hub Network → Spoke Network → VMs
```

### 🛠️ VPN Setup Instructions

#### Prerequisites
1. **Azure AD Tenant ID** - Required for authentication configuration
2. **Azure VPN Client** - Download from Microsoft Store
3. **Proper Azure AD Permissions** - Access to the subscription

#### Step 1: Configure VPN Gateway
```hcl
# In terraform.tfvars, add your Azure AD Tenant ID
aad_tenant_id = "your-tenant-id-here"
```

#### Step 2: Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

#### Step 3: Retrieve VPN Configuration
After deployment, the VPN client configuration is automatically stored in Key Vault:

```bash
# Get the Key Vault secret name from Terraform output
terraform output vpn_client_config_secret

# Secret name format: {PREFIX}-HUB-VGW-client-config
# Example: US1-BOFA-CS-HUB-VGW-client-config
```

#### Step 4: Download & Install Azure VPN Client
1. **Microsoft Store** → Search "Azure VPN Client"
2. **Install** the official Microsoft Azure VPN Client

#### Step 5: Import VPN Profile
1. **Open Azure VPN Client**
2. **Add Profile** → Import from Azure
3. **Use Download URL** from Key Vault secret
4. **Alternative**: Manual configuration with AAD settings from Key Vault

#### Step 6: Connect & Access Resources
1. **Connect** using your Azure AD credentials
2. **Verify Connection** - You'll get an IP like `172.16.0.x`
3. **Access VMs** using their private IP addresses

### 🖥️ Accessing Virtual Machines

#### Network Flow
```
Your Device (172.16.0.x) → Hub Network → Spoke Network → VM (10.223.44.x)
```

#### VM Access Methods
1. **RDP via Private IP** (Recommended)
   ```bash
   # Get VM private IP from Terraform output
   terraform output windows_servers

   # Connect via RDP
   mstsc /v:10.223.44.10
   ```

2. **Azure Bastion** (Web-based, if deployed)
   - Azure Portal → VM → Connect → Bastion

#### VM Network Configuration
- **Subnet**: WEB-SUBNET (`10.223.44.0/24`)
- **Private IP**: Automatically assigned (e.g., `10.223.44.4`)
- **Public IP**: Disabled (more secure)
- **RDP Access**: Allowed from `VirtualNetwork` (includes VPN clients)
- **Computer Name**: Auto-shortened to 15 characters for Windows compatibility

### 🔑 Key Vault Integration

The VPN gateway configuration is automatically stored in Azure Key Vault for secure access and centralized management.

#### 📦 What Gets Stored in Key Vault

The infrastructure automatically creates **two Key Vault secrets** for VPN management:

##### 1. VPN Client Configuration (Main Secret)
**Secret Name**: `{PREFIX}-HUB-VGW-client-config`
**Example**: `US1-BOFA-CS-HUB-VGW-client-config`
**Content Type**: `application/json`

Complete VPN configuration including all connection details:
```json
{
  "gateway_name": "US1-BOFA-CS-HUB-VGW",
  "gateway_id": "/subscriptions/.../virtualNetworkGateways/US1-BOFA-CS-HUB-VGW",
  "public_ip_address": "20.12.34.56",
  "vpn_client_config": {
    "address_space": ["172.16.0.0/24"],
    "aad_tenant_id": "your-tenant-id",
    "aad_audience": "41b23e61-6c1e-4545-b367-cd054e0ed4b4",
    "aad_issuer": "https://sts.windows.net/your-tenant-id/",
    "vpn_client_protocols": ["OpenVPN"],
    "download_url": "https://management.azure.com/subscriptions/.../generatevpnclientpackage?api-version=2021-02-01"
  },
  "connection_instructions": {
    "step1": "Download Azure VPN Client from Microsoft Store",
    "step2": "Import the VPN profile using the download URL above",
    "step3": "Connect using your Azure AD credentials",
    "step4": "Verify connection to hub network: 10.223.40.0/24"
  }
}
```

##### 2. Root Certificate (Optional)
**Secret Name**: `{PREFIX}-HUB-VGW-root-certificate`
**Example**: `US1-BOFA-CS-HUB-VGW-root-certificate`
**Content Type**: `application/x-pkcs12`
**Note**: Only created if certificate authentication is configured (not used with Azure AD auth)

#### 🎯 Why Store Configuration in Key Vault?

##### Security Benefits
- **Encrypted Storage**: All VPN configuration encrypted at rest
- **Access Control**: RBAC controls who can retrieve VPN settings
- **Audit Logs**: Track who accessed VPN configuration and when
- **Centralized Security**: Single location for all sensitive VPN data

##### Operational Benefits
- **Easy Retrieval**: Get configuration via Azure CLI, Portal, or API
- **Automation Ready**: Scripts and applications can pull config programmatically
- **Version Control**: Key Vault maintains secret versions automatically
- **Integration**: Other Azure services can reference the configuration
- **Single Source of Truth**: Eliminates configuration drift and manual distribution

#### 🔍 How to Access VPN Configuration

##### Method 1: Via Terraform Output
```bash
# Get the secret name from Terraform
terraform output vpn_client_config_secret
# Returns: "US1-BOFA-CS-HUB-VGW-client-config"

# Get the Key Vault name
terraform output hub_key_vault_name
# Returns: "US1-BOFA-CS-HUB-KV"
```

##### Method 2: Via Azure CLI
```bash
# Get the full VPN configuration
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --query "value" -o tsv

# Get just the download URL for VPN profile
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --query "value" -o tsv | jq -r '.vpn_client_config.download_url'
```

##### Method 3: Via Azure Portal
```
Azure Portal → Key Vaults → US1-BOFA-CS-HUB-KV → Secrets → US1-BOFA-CS-HUB-VGW-client-config
```

##### Method 4: Via PowerShell
```powershell
# Get VPN configuration via PowerShell
Get-AzKeyVaultSecret -VaultName "US1-BOFA-CS-HUB-KV" -Name "US1-BOFA-CS-HUB-VGW-client-config" -AsPlainText
```

#### 🔐 Access Control for Key Vault Secrets

##### Required Permissions
To access VPN configuration, users need:
- **Key Vault Secrets User** role, or
- **Key Vault Reader** + **Key Vault Secrets Officer** roles, or
- Custom role with `Microsoft.KeyVault/vaults/secrets/getSecret/action` permission

##### Example RBAC Assignment
```bash
# Grant user access to read Key Vault secrets
az role assignment create \
  --assignee "user@company.com" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/US1-BOFA-CS-HUB-RG/providers/Microsoft.KeyVault/vaults/US1-BOFA-CS-HUB-KV"
```

#### 🔄 Automated VPN Profile Distribution

The Key Vault integration enables automated VPN profile distribution:

##### For IT Administrators
```bash
#!/bin/bash
# Script to distribute VPN profiles to users

VAULT_NAME="US1-BOFA-CS-HUB-KV"
SECRET_NAME="US1-BOFA-CS-HUB-VGW-client-config"

# Get VPN configuration
VPN_CONFIG=$(az keyvault secret show --vault-name $VAULT_NAME --name $SECRET_NAME --query "value" -o tsv)

# Extract download URL
DOWNLOAD_URL=$(echo $VPN_CONFIG | jq -r '.vpn_client_config.download_url')

# Send to users via email/portal/etc
echo "VPN Profile Download URL: $DOWNLOAD_URL"
```

##### For End Users
```bash
# Simple user script to get VPN connection info
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --query "value" -o tsv | jq '.connection_instructions'
```

#### 🔧 Key Vault Secret Management

##### Viewing Secret Versions
```bash
# List all versions of the VPN config secret
az keyvault secret list-versions \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config"
```

##### Backup and Restore
```bash
# Backup VPN configuration
az keyvault secret backup \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --file vpn-config-backup.blob

# Restore if needed (to different vault)
az keyvault secret restore \
  --vault-name "NEW-VAULT-NAME" \
  --file vpn-config-backup.blob
```

This Key Vault integration provides **enterprise-grade secret management** for your VPN infrastructure, ensuring secure, auditable, and automated access to VPN configurations.

### 🌐 Network Topology with VPN

```
Internet
    ↓
VPN Gateway (Hub) ←── VPN Clients (172.16.0.0/24)
    ↓
Hub Network (10.223.40.0/24)
    ↓ (VNet Peering)
Spoke Network (10.223.44.0/22)
    ↓
├── Web Subnet (10.223.44.0/24) ← VMs here
├── App Subnet (10.223.45.0/24)
├── DB Subnet (10.223.46.0/24)
└── DevOps Subnet (10.223.47.0/24)
```

### 🛡️ Security Best Practices

#### Identity-Based Security
- **Azure AD Authentication**: Only authorized users can connect to VPN
- **No Certificate Management**: No need to distribute certificates
- **Conditional Access**: Can be enforced via Azure AD policies
- **MFA Support**: Multi-factor authentication available

#### Network Security
- **Private IP Access**: VMs have no public IPs
- **Network Segmentation**: Clear separation between hub/spoke/client networks
- **Encrypted Tunnels**: All VPN traffic is encrypted end-to-end
- **Least Privilege**: RDP access limited to authenticated VPN users

#### Operational Security
- **Configuration in Key Vault**: Secure storage of VPN settings
- **Terraform State**: Infrastructure as Code with version control
- **Audit Trails**: Azure AD authentication logs available
- **Centralized Management**: Single hub gateway for all remote access

### 🔧 Troubleshooting VPN Connection

#### Common Issues
1. **Cannot Download VPN Profile**
   - Verify Azure AD permissions
   - Check tenant ID configuration
   - Ensure VPN gateway is fully deployed

2. **Authentication Failures**
   - Verify you're using correct Azure AD credentials
   - Check if MFA is required
   - Confirm user has appropriate permissions

3. **Cannot Access VMs**
   - Verify VPN connection is active (check your IP: `ipconfig`)
   - Confirm VM private IP address
   - Check NSG rules allow RDP from VirtualNetwork

4. **VPN Client Connection Issues**
   - Ensure using official Microsoft Azure VPN Client
   - Try importing profile again
   - Check Windows firewall settings

#### Network Verification
```bash
# Check your VPN-assigned IP
ipconfig /all

# Test connectivity to hub network
ping 10.223.40.1

# Test connectivity to spoke network
ping 10.223.44.1

# Test RDP connectivity to VM
telnet 10.223.44.10 3389
```

## 📋 Client Setup & Configuration

### 🎯 Client VPN Access Documentation

The infrastructure includes comprehensive client documentation for VPN access:

#### **📁 Available Documentation Files:**
- **`Azure_VPN_Client_Setup_Guide.md`** - Complete client setup instructions
- **`extract_vpn_config.sh`** - Script to extract live configuration values
- **`vpn_client_config.txt`** - Generated client configuration summary

#### **📱 Quick Client Setup Process:**

##### **Step 1: Extract Current Configuration**
```bash
# Run the configuration extraction script
./extract_vpn_config.sh

# This generates vpn_client_config.txt with live values
```

##### **Step 2: Client Software Installation**
1. **Install Azure VPN Client** from Microsoft Store
2. **Download Remote Desktop** (if not already installed)

##### **Step 3: VPN Profile Import**
1. **Get profile URL** from Key Vault secret: `US1-BOFA-CS-HUB-VGW-client-config`
2. **Import in Azure VPN Client** using the download URL
3. **Connect using Azure AD credentials**

##### **Step 4: VM Access**
```bash
# RDP to VM using private IP
mstsc /v:10.223.44.x

# Credentials:
# Username: webadmin
# Password: From Key Vault secret US1-BOFA-CS-WEB-VM01-admin-password
```

### 🔑 Configuration Extraction Commands

#### **Get VPN Configuration from Key Vault:**
```bash
# Get complete VPN client configuration
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --query "value" -o tsv

# Get just the profile download URL
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --query "value" -o tsv | jq -r '.vpn_client_config.download_url'
```

#### **Get VM Access Information:**
```bash
# Get VM private IP
az vm show \
  --resource-group "US1-BOFA-CS-SPOKE-RG" \
  --name "US1-BOFA-CS-WEB-VM01" \
  --show-details \
  --query privateIps -o tsv

# Get VM admin password
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-WEB-VM01-admin-password" \
  --query value -o tsv
```

#### **Get VPN Gateway Status:**
```bash
# Check VPN gateway deployment status
az network vnet-gateway show \
  --resource-group "US1-BOFA-CS-HUB-RG" \
  --name "US1-BOFA-CS-HUB-VGW" \
  --query provisioningState

# Get VPN gateway public IP
az network public-ip show \
  --resource-group "US1-BOFA-CS-HUB-RG" \
  --name "US1-BOFA-CS-HUB-VGW-PIP" \
  --query ipAddress -o tsv
```

### 👥 Client Information Summary

#### **VPN Connection Details:**
- **Gateway Name**: `US1-BOFA-CS-HUB-VGW`
- **Authentication**: Azure Active Directory
- **Tenant**: `certentbofaproduction.onmicrosoft.com`
- **Protocol**: OpenVPN
- **Client IP Range**: `172.16.0.0/24`

#### **VM Access Details:**
- **VM Name**: `US1-BOFA-CS-WEB-VM01`
- **Private IP**: Dynamic (check via extraction script)
- **Username**: `webadmin`
- **Computer Name**: `US1BOFACSWEBV01` (Windows 15-char limit)
- **RDP Port**: 3389
- **Accessible Networks**: Hub (`10.223.40.0/24`) + Spoke (`10.223.44.0/22`)

#### **Security & Compliance:**
- **Encryption**: End-to-end encrypted VPN tunnel
- **Authentication**: Azure AD with MFA support
- **Access Control**: Identity-based (no shared keys/certificates)
- **Audit Trail**: All connections logged in Azure AD
- **Network Security**: Private IPs only, no internet exposure

### 🚀 Automated Client Distribution

#### **For IT Administrators:**
```bash
# Generate complete client package
./extract_vpn_config.sh

# Distribute to clients:
# 1. Azure_VPN_Client_Setup_Guide.md (setup instructions)
# 2. vpn_client_config.txt (specific configuration values)
# 3. VM credentials (from Key Vault)
```

#### **Client Quick Reference:**
```
╔══════════════════════════════════════════════════╗
║           Azure VPN Quick Reference              ║
╠══════════════════════════════════════════════════╣
║ 1. Install: Microsoft Store → Azure VPN Client  ║
║ 2. Import: Use profile URL from IT              ║
║ 3. Connect: Azure AD credentials                ║
║ 4. Access: RDP to VM private IP                 ║
║ 5. Support: Contact IT for assistance           ║
╚══════════════════════════════════════════════════╝
```

### 📞 Support Information

#### **For Configuration Issues:**
- **Key Vault Access**: Ensure proper RBAC permissions
- **VPN Profile**: Use the extraction script for current URLs
- **VM Credentials**: Retrieve from Key Vault secrets
- **Network Access**: Verify VPN client gets `172.16.0.x` IP

#### **Client Support Scripts:**
```bash
# Verify client VPN connection
ipconfig /all | findstr "172.16.0"

# Test hub connectivity
ping 10.223.40.1

# Test VM connectivity
ping 10.223.44.4
telnet 10.223.44.4 3389
```

## Monitoring and Management

### Centralized Services (Hub)
- **DNS Resolution** for internal name resolution
- **Domain Controllers** for identity management
- **Key Vault** for secrets and certificate management
- **Jump Boxes** for secure administrative access
- **Monitoring** infrastructure for logging and alerting

### Application Services (Spoke)
- **Load Balancing** for high availability
- **Container Registry** for private container images
- **Database Services** with private endpoints
- **DevOps Integration** for CI/CD pipelines

## Best Practices

### Naming
- Always use **UPPER CASE** for all resource names
- Follow the **standardized naming convention**
- Use **consistent abbreviations** (ADO for Azure DevOps, RG for Resource Group)
- Include **environment indicators** for easy identification

### Network Design
- **Maintain IP address planning** documentation
- **Reserve IP ranges** for future expansion
- **Document service endpoints** for each subnet
- **Plan for DR/backup** connectivity requirements

### Security
- **Implement least privilege** access principles
- **Use managed identities** where possible
- **Enable monitoring and logging** on all resources
- **Regular security reviews** of network configurations

## Troubleshooting

### Common Issues

1. **Circular Dependencies**
   - VNet peering is configured separately from VNet modules to avoid circular dependencies

2. **Name Length Limits**
   - Azure resource names have character limits; adjust variables if names exceed limits

3. **IP Address Conflicts**
   - Ensure CIDR blocks don't overlap with existing networks

### Support

For issues or questions:
1. Check Azure documentation for resource-specific requirements
2. Review Terraform Azure Provider documentation
3. Validate variable values and naming conventions
4. Ensure proper Azure permissions for resource creation

## 🖥️ BOFA VM Deployment & Configuration

### Overview

The infrastructure includes comprehensive **Windows Server deployment with automated BOFA-specific configuration**. This eliminates manual server setup and ensures consistent, reliable deployments across environments.

### 🚀 Complete Automation Features

#### ✅ **100% Automated BOFA Requirements**
- **Disk Provisioning** - Automated E: and R: drive setup (role-specific)
- **Domain Join** - Automatic join to `CertentEMBOFA.Prod` with restart handling
- **Server Roles** - IIS for Web servers, App services for App servers
- **ASP.NET Installation** - Both 6.0.26 and 8.0.18 hosting bundles
- **DevOps Access** - `BOFAProd_DevOps` group added to local administrators
- **Security Tools** - SentinelOne and Tanium automated installation
- **Oracle Client** - Full Oracle 19.3 client installation from BOFA storage
- **gMSA Configuration** - Service account setup with environment awareness
- **Datadog Agent** - Environment-specific monitoring with proper tags
- **GPG Tools** - GnuPG/GPG4Win for encryption/signing capabilities

#### 🔄 **Restart-Resilient Architecture**
- **Smart Restart Handling** - Domain join triggers restart, then continues automatically
- **Marker File System** - Tracks completion state across reboots
- **Sequential Execution** - Proper order with dependency awareness
- **Error Recovery** - Graceful handling of missing components

### 🏗️ VM Deployment Architecture

#### **VM Specifications**
| Component | Web Server | App Server |
|-----------|-----------|------------|
| **VM Size** | `Standard_B4ms` | `Standard_B4ms` |
| **OS Disk** | 128GB Premium SSD | 128GB Premium SSD |
| **Data Disks** | F: (128GB), R: (50GB) | E: (128GB), R: (50GB) |
| **Network** | WEB-SUBNET | APP-SUBNET |
| **Public IP** | Disabled (VPN access only) | Disabled (VPN access only) |
| **Windows SKU** | 2022-datacenter-azure-edition-hotpatch | 2022-datacenter-azure-edition-hotpatch |

#### **Automated PowerShell Scripts**
The deployment uses **8 PowerShell scripts** automatically uploaded from Git:

1. **`Provisioning_disks_WEB.ps1`** / **`Provisioning_disks_APP.ps1`** - Role-specific disk setup
2. **`BOFA_domain_join.ps1`** - Domain join with restart handling
3. **`web-server-roles.ps1`** / **`app-server-roles.ps1`** - Server role configuration
4. **`SentinelOne_install.ps1`** - Security agent installation
5. **`Tanium_install_script.ps1`** - Endpoint management
6. **`Oracle_client_install.ps1`** - Oracle client from BOFA storage
7. **`gMSA_configuration.ps1`** - Service account management
8. **`Datadog_GPG_install.ps1`** - Monitoring and encryption tools

### 📦 Storage Account Integration

#### **Automatic Script Upload**
- **Git-Based Deployment** - Scripts automatically extracted from master branch
- **Azure Storage Integration** - Uploaded to blob storage during deployment
- **Version Control** - MD5 checksums ensure file integrity
- **Public Blob Access** - VMs can download scripts securely

#### **BOFA-Specific Oracle Client**
Uses the exact BOFA Oracle client package:
```powershell
# Oracle client URL from BOFA environment
$OracleClientURL = "https://usngdevenvaddons.blob.core.windows.net/quarter1/Oracle_Install_WINDOWS.X64_193000_client.zip?sp=r&st=2025-08-07T20:13:29Z&se=2026-08-08T04:28:29Z&spr=https&sv=2024-11-04&sr=b&sig=%2B7iurY8GcEOvqcZMf3VHhDnP%2Fhxzr88X3XrzF7hWSSY%3D"
```

### 🔧 Deployment Process

#### **1. Infrastructure Deployment**
```bash
# Deploy complete infrastructure including VMs
terraform init
terraform plan
terraform apply
```

#### **2. Automatic VM Configuration**
Once VMs are created, the **single comprehensive VM extension** handles all configuration:

##### **Stage 1: Infrastructure Setup**
- Disk provisioning with drive letters (F:/R: for Web, E:/R: for App)
- DVD drive relocation to avoid conflicts

##### **Stage 2: Domain Integration**
- Join to `CertentEMBOFA.Prod` domain
- Automatic restart with continuation logic
- Creates marker files to prevent duplicate operations

##### **Stage 3: Platform Installation**
- Windows Server roles (IIS for Web, App services for App)
- ASP.NET Core 6.0.26 hosting bundle
- ASP.NET Core 8.0.18 hosting bundle
- DevOps group (`BOFAProd_DevOps`) added to local administrators

##### **Stage 4: Security Tools**
- SentinelOne agent installation and configuration
- Tanium endpoint management deployment

##### **Stage 5: Additional Software**
- Oracle 19.3 client installation from BOFA storage
- gMSA service account configuration
- Datadog monitoring agent with environment-specific tags
- GPG tools for encryption/signing capabilities

### 🔑 Credential Management

#### **Secure Password Storage**
- **Random Generation** - 16-character complex passwords
- **Key Vault Storage** - All VM passwords stored securely
- **Secret Names** - `{VM-NAME}-admin-password`

#### **Access Credentials**
```bash
# Get VM admin password from Key Vault
az keyvault secret show \
  --vault-name "US1-BOFA-CS-SPOKE-KV" \
  --name "US1-BOFA-CS-WEB-VM01-admin-password" \
  --query value -o tsv

# VM Access Details:
# Username: webadmin (Web server) / appadmin (App server)
# Computer Name: US1BOFACSWEBV01 / US1BOFACSAPPV01
# Access Method: RDP via VPN (172.16.0.x → 10.223.44.x/10.223.45.x)
```

### 🌐 Network Access

#### **VPN-Based Access**
- **No Public IPs** - All VMs use private IPs only
- **VPN Gateway Access** - Connect via Point-to-Site VPN
- **Network Segmentation** - Web subnet (10.223.44.0/24), App subnet (10.223.45.0/24)

#### **RDP Access Flow**
```
VPN Client (172.16.0.x) → Hub Network → Spoke Network → VM (Private IP)
```

#### **Security Configuration**
- **RDP Access** - Allowed from VirtualNetwork (includes VPN clients)
- **Network Security Groups** - Proper subnet-level security
- **Domain Integration** - Full Active Directory authentication

### 📊 Environment Configuration

#### **Environment Variables**
The deployment is **environment-aware** with automatic configuration:

| Environment | Domain | OU Path | DevOps Group |
|-------------|--------|---------|--------------|
| **Prod** | `CertentEMBOFA.Prod` | `OU=AADDC Computers,DC=CertentEMBOFA,DC=Prod` | `BOFAProd_DevOps` |
| **Dev** | `CertentEMBOFA.Dev` | `OU=AADDC Computers,DC=CertentEMBOFA,DC=Dev` | `BOFADev_DevOps` |

#### **Datadog Configuration**
- **Environment Tags** - `env:prod,client:bofa,tier:application`
- **Site Configuration** - `datadoghq.com`
- **API Key** - Retrieved from environment configuration or Key Vault

### 🔍 Monitoring & Logging

#### **Deployment Monitoring**
- **VM Extension Logs** - Available in Azure Portal → VM → Extensions
- **PowerShell Execution** - Detailed logging with color-coded output
- **Error Handling** - Comprehensive error reporting and recovery

#### **Application Monitoring**
- **Datadog Agent** - Automatic installation with environment-specific configuration
- **Log Collection** - Enabled for application and system logs
- **Process Monitoring** - Track application and system processes

### 🛠️ Troubleshooting

#### **Common Scenarios**

##### **Domain Join Issues**
- **Check DNS** - Ensure VMs can resolve domain controllers
- **Verify Credentials** - Domain join uses service account `svc_domainjoin`
- **Network Access** - Confirm connectivity to domain controllers

##### **Script Execution Problems**
- **Storage Access** - Verify VM can access storage account
- **PowerShell Execution Policy** - Scripts run with `Unrestricted` policy
- **File Downloads** - Check script URLs in storage account

##### **Oracle Client Issues**
- **Download Verification** - Confirm BOFA storage URL accessibility
- **Installation Logs** - Check `C:\temp\oracle_install` for details
- **Environment Variables** - Verify `ORACLE_HOME` and `PATH` settings

#### **Debugging Commands**
```bash
# Check VM extension status
az vm extension show \
  --resource-group "US1-BOFA-CS-SPOKE-RG" \
  --vm-name "US1-BOFA-CS-WEB-VM01" \
  --name "US1-BOFA-CS-WEB-VM01-BOFA-Configuration-Extension"

# Get extension execution output
az vm run-command invoke \
  --resource-group "US1-BOFA-CS-SPOKE-RG" \
  --name "US1-BOFA-CS-WEB-VM01" \
  --command-id RunPowerShellScript \
  --scripts "Get-EventLog -LogName Application -Source 'CustomScriptExtension' -Newest 10"
```

### 📋 Manual Tasks (If Any)

The system handles **100% of BOFA requirements automatically**. However, if customization is needed:

#### **Optional Manual Configuration**
- **Custom Oracle TNS Names** - Edit `tnsnames.ora` for specific databases
- **Additional SSL Certificates** - Install if required for applications
- **Custom Application Configuration** - Environment-specific app settings
- **Backup Configuration** - Set up application-specific backup jobs

#### **Validation Steps**
After deployment, verify:
- ✅ Domain membership: `Get-ComputerInfo | Select WindowsDomainName`
- ✅ Drive configuration: `Get-Disk | Format-Table`
- ✅ IIS installation (Web servers): `Get-WindowsFeature -Name IIS-*`
- ✅ ASP.NET versions: `Get-ChildItem "HKLM:\SOFTWARE\Microsoft\ASP.NET Core"`
- ✅ Oracle client: `$env:ORACLE_HOME` and `tnsping`
- ✅ Security tools: Services for SentinelOne and Tanium
- ✅ Datadog agent: `Get-Service -Name "DatadogAgent"`

### 🎯 Key Benefits

#### **Operational Excellence**
- **Zero Manual Setup** - Complete automation from infrastructure to applications
- **Consistent Configuration** - No human error or configuration drift
- **Rapid Deployment** - Full BOFA-ready server in ~30 minutes
- **Environment Parity** - Identical setup across Dev/Test/Prod

#### **Security & Compliance**
- **No Public Access** - VPN-only access model
- **Credential Management** - All passwords in Key Vault
- **Domain Integration** - Full Active Directory authentication
- **Security Tooling** - Automated SentinelOne and Tanium deployment
- **Audit Trail** - Complete deployment logging and monitoring

#### **Developer Productivity**
- **Ready-to-Use Servers** - No waiting for manual configuration
- **Standard Toolchain** - Oracle client, ASP.NET, all dev tools included
- **Development Focus** - Developers can focus on applications, not infrastructure
- **Self-Service Model** - Deploy new environments via Terraform

This comprehensive automation ensures **BOFA environments are deployed consistently, securely, and efficiently** with minimal manual intervention required.

## Contributing

1. Follow the established naming conventions
2. Update documentation for any changes
3. Test changes in development environment first
4. Maintain backward compatibility where possible

## License

[Add appropriate license information]

---

**Note**: This infrastructure template provides the foundation for Azure networking. Additional security, monitoring, and application-specific resources should be added based on specific requirements.