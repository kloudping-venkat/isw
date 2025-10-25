# Azure Modules Changelog

All notable changes to the Azure modules will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-14

### Added
- Initial release of Azure modules
- AKS module for Kubernetes clusters
- Application Gateway module with WAF support
- Compute module for virtual machines
- Database module for Oracle VMs
- Key Vault module
- NAT Gateway module
- Networking module (VNet, Subnets, NSG)
- Resource Group module
- SFTP module for storage accounts
- VNet Peering module
- VPN Gateway module with Azure AD authentication

### Module Structure
```
modules/azure/
├── aks/
├── application-gateway/
├── compute/
├── db/
├── keyvault/
├── nat-gateway/
├── networking/
├── rg/
├── sftp/
├── storage-scripts/
├── vnet-peering/
└── vpn-gateway/
```

### Versioning Policy
- **Major version (X.0.0)**: Breaking changes, major refactoring
- **Minor version (0.X.0)**: New features, backward compatible
- **Patch version (0.0.X)**: Bug fixes, documentation updates

## Future Releases

### [Unreleased]
- Performance optimizations
- Additional Azure services support
