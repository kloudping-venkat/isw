# Subnet Configuration

## Overview

As of this change, subnet configurations are now **environment-specific** and defined in each environment's tfvars file instead of being hardcoded in main.tf.

## Why This Change?

**Problem**: Subnets were hardcoded in main.tf with CS IP ranges (10.223.x.x), causing errors when deploying Walmart with different IP ranges (10.225.x.x):
```
Error: Subnet 'US1-WM-P-SPOKE-APP-SUBNET' is not valid because its IP address
range is outside the IP address range of virtual network 'US1-WM-P-SPOKE-VNET'.
```

**Solution**: Move subnet definitions to tfvars files so each environment can define its own subnet ranges.

## Configuration

### Variable Definition

In `variables.tf`:
```hcl
variable "spoke_subnets" {
  description = "Spoke VNet subnets configuration"
  type = map(object({
    address_prefix    = string
    service_endpoints = list(string)
  }))
  default = { ... }  # CS defaults
}
```

### Main.tf Usage

In `main.tf`:
```hcl
module "spoke_vnet" {
  source = "./modules/azure"

  vnet_address_space = [var.spoke_vnet_address_space]
  subnets            = var.spoke_subnets  # ← Uses variable
  ...
}
```

### Environment-Specific Configuration

#### CS Environment (`environments/em_bofa/cs.tfvars`)

Uses default values from variables.tf (CS ranges):
```hcl
spoke_vnet_address_space = "10.223.48.0/21"
# spoke_subnets uses defaults (10.223.48.0/24, 10.223.49.0/24, etc.)
```

#### Walmart Environment (`environments/em_bofa/walmart.tfvars`)

Overrides with Walmart-specific ranges:
```hcl
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
  # ... etc
}
```

## Subnet Naming Convention

All subnets follow this pattern:
- **WEB-SUBNET**: Web tier VMs
- **APP-SUBNET**: Application tier VMs
- **DB-SUBNET**: Database tier VMs
- **ADO-SUBNET**: Azure DevOps agents
- **LOGI-SUBNET**: Logi AKS cluster
- **AG-SUBNET**: Application Gateway (dedicated)
- **SFTP-SUBNET**: SFTP storage private endpoints

The prefix (e.g., `US1-BOFA-CS-SPOKE-`) is automatically added by main.tf using `${local.prefix}-SPOKE-`.

## IP Allocation

### CS Environment
- **VNet**: 10.223.48.0/21 (2048 IPs)
- **Subnets**: 10.223.48.0/24 through 10.223.54.0/24

### Walmart Environment
- **VNet**: 10.225.0.0/21 (2048 IPs)
- **Subnets**: 10.225.0.0/24 through 10.225.6.0/24

Each subnet is a /24 providing 256 IPs (251 usable after Azure reserved IPs).

## Service Endpoints

Service endpoints enable secure connectivity from subnets to Azure PaaS services:

| Subnet | Service Endpoints |
|--------|------------------|
| WEB | Storage, KeyVault, Web |
| APP | Storage, KeyVault, Sql |
| DB | Storage, KeyVault, Sql |
| ADO | Storage, KeyVault, ContainerRegistry |
| LOGI | Storage, KeyVault, ContainerRegistry |
| AG | None (Application Gateway) |
| SFTP | Storage, KeyVault |

## Adding New Environments

When creating a new environment:

1. Choose a non-overlapping VNet CIDR (e.g., 10.226.0.0/21)
2. Define spoke_subnets in the new tfvars file
3. Ensure subnet ranges are within the VNet CIDR
4. Use the same subnet naming convention for consistency

Example for a new environment:
```hcl
spoke_vnet_address_space = "10.226.0.0/21"

spoke_subnets = {
  "WEB-SUBNET" = {
    address_prefix    = "10.226.0.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Web"]
  }
  # ... etc
}
```

## Benefits

1. **Flexibility**: Each environment can have unique IP ranges
2. **No conflicts**: Walmart can use 10.225.x.x while CS uses 10.223.x.x
3. **Maintainability**: Subnet config lives with environment config
4. **Scalability**: Easy to add new environments with different ranges

---

**Migration Status**: ✅ Completed
- main.tf updated to use variable
- variables.tf updated with new variable
- walmart.tfvars configured with Walmart IP ranges
- CS continues using default ranges
