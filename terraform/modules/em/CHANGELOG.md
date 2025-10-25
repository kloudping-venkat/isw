# EM Module Changelog

All notable changes to the EM Module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-14

### Added
- Complete restructure into product/environment-based deployment model
- Support for multiple products: EM, BAML, EM_NEXTGEN
- Support for multiple environments: dev, prod, cs, walmart
- Hub-spoke architecture with VNet peering
- Web tier with Application Gateway and WAF
- App tier with application servers
- Database tier with Oracle VMs
- AKS cluster for Logi Analytics
- SFTP infrastructure with private endpoints
- VPN Gateway with Azure AD authentication
- DevOps agent VMs
- Automated deployment pipeline

### Changed
- **BREAKING**: Module path changed from `./modules/em` to `./modules/azure`
- **BREAKING**: Environment configuration now uses product-specific tfvars
- Reorganized directory structure for better scalability
- Updated all module references to use new paths

### Dependencies
- Azure Modules: v1.0.0
- Terraform: >= 1.5.0
- AzureRM Provider: ~> 3.0

### Infrastructure Components
- Hub VNet with 4 subnets (Gateway, Bastion, Shared Services, Management)
- Spoke VNet with 7 subnets (Web, App, DB, ADO, Logi, AG, SFTP)
- Application Gateway with multi-site hosting
- AKS cluster with system and workload node pools
- Oracle database VMs with cloud-init preparation
- SFTP storage with BlockBlobStorage and HNS

## [1.x.x] - Previous Versions

### Legacy Structure
- Single environment deployments
- Manual module path management
- Limited product support

## Version Compatibility

### Supported Combinations

| EM Module | Azure Modules | Products              | Environments        |
|-----------|---------------|-----------------------|---------------------|
| 2.0.0     | 1.0.0         | em, baml, em_nextgen  | dev, prod, cs, walmart |
| 1.x.x     | 1.0.0         | Legacy                | Single environment  |

## Upgrade Guide

### From 1.x.x to 2.0.0

1. **Backup State Files**
   ```bash
   terraform state pull > backup-state.json
   ```

2. **Update Module References**
   ```hcl
   # Old
   module "infrastructure" {
     source = "./modules/em"
   }

   # New
   module "infrastructure" {
     source = "./modules/azure"
   }
   ```

3. **Migrate Configuration Files**
   - Move tfvars to `environments/{product}/{environment}.tfvars`
   - Update variable references

4. **Run Migration**
   ```bash
   terraform init -upgrade
   terraform plan -var-file="environments/baml/prod.tfvars"
   ```

## Future Releases

### [Unreleased]
- Multi-region support
- Disaster recovery automation
- Cost optimization features
- Enhanced monitoring and alerting

### Planned for 2.1.0
- Azure Front Door integration
- Private Link support for all services
- Enhanced AKS security features
- Backup and recovery automation

### Planned for 3.0.0
- Multi-cloud support
- GitOps workflow integration
- Infrastructure as Code testing framework
- Automated compliance checking
