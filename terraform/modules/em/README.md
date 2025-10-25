# EM Module

**Version:** 2.0.0
**Azure Modules Version:** 1.0.0

## Overview

This module provides a high-level abstraction for deploying EM NextGen infrastructure on Azure. It orchestrates multiple Azure modules to create a complete hub-spoke architecture with all necessary components.

## Module Architecture

```
EM Module (v2.0.0)
│
├── Uses: Azure Modules (v1.0.0)
│   ├── networking
│   ├── compute
│   ├── aks
│   ├── application-gateway
│   ├── database
│   ├── keyvault
│   ├── sftp
│   └── vpn-gateway
│
└── Provides: Complete EM Environment
    ├── Hub VNet with VPN Gateway
    ├── Spoke VNet with Application Subnets
    ├── Web Tier (IIS VMs + App Gateway)
    ├── App Tier (Application VMs)
    ├── Database Tier (Oracle VMs)
    ├── AKS Cluster (Logi Analytics)
    ├── SFTP Storage
    └── DevOps Agents
```

## Versioning Strategy

### EM Module Versions (this module)
- **Version Format:** `MAJOR.MINOR.PATCH`
- **Current Version:** 2.0.0
- **Stability:** Production-ready

Version increments:
- **MAJOR (X.0.0)**: Architectural changes, breaking API changes
- **MINOR (0.X.0)**: New EM features, new component additions
- **PATCH (0.0.X)**: Bug fixes, configuration updates

### Azure Modules Version (dependencies)
- **Referenced Version:** 1.0.0
- **Location:** `../azure/`
- **Compatibility:** This module is tested with Azure modules v1.0.0

## Usage

### Basic Usage

```hcl
module "em_environment" {
  source = "./modules/em"

  # Version pinning (optional but recommended)
  # version = "2.0.0"  # Use when published to registry

  # Basic Configuration
  location_code = "US1"
  client        = "BAML"
  environment   = "PROD"
  location      = "East US"

  # Network Configuration
  hub_vnet_address_space   = "10.224.40.0/24"
  spoke_vnet_address_space = "10.224.48.0/21"

  # Feature Flags
  enable_vpn_gateway = true
  enable_aks_cluster = true
  enable_sftp        = true

  tags = {
    Environment = "PROD"
    ManagedBy   = "Terraform"
  }
}
```

### Version Pinning in Environments

For production stability, pin module versions in your environment configurations:

```hcl
# environments/baml/prod.tfvars
em_module_version   = "2.0.0"  # EM Module
azure_module_version = "1.0.0"  # Azure Base Modules
```

## Version Compatibility Matrix

| EM Infrastructure | Azure Modules | Terraform | AzureRM Provider |
|-------------------|---------------|-----------|------------------|
| 2.0.0             | 1.0.0         | >= 1.5.0  | ~> 3.0           |
| 1.x.x             | 1.0.0         | >= 1.5.0  | ~> 3.0           |

## Change Management

### When to Update Versions

1. **Azure Modules Updated (1.0.0 → 1.1.0)**
   - Test in dev environment
   - Update `versions.tf` to reference new version
   - Increment EM Infrastructure patch version (2.0.0 → 2.0.1)
   - Deploy to higher environments

2. **New EM Feature Added**
   - Add new feature to EM Infrastructure module
   - Increment minor version (2.0.0 → 2.1.0)
   - Update documentation
   - Test in dev before prod

3. **Breaking Change**
   - Major architectural change
   - Increment major version (2.0.0 → 3.0.0)
   - Provide migration guide
   - Coordinate with all teams

## Outputs

This module exposes all necessary outputs from underlying Azure modules:

- VNet IDs and names
- Subnet IDs
- VM information
- AKS cluster details
- Key Vault IDs
- Application Gateway details

## Support

For issues or questions:
- Check CHANGELOG.md for recent changes
- Review Azure modules documentation
- Contact CloudOps team

## License

Internal use only - Insight Software
