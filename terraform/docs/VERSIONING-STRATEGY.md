# Module Versioning Strategy

## Overview

This document describes the versioning strategy for EM NextGen Infrastructure as Code (IaC) modules.

## Module Architecture

```
Root Configuration (main.tf)
    │
    ├─── Uses EM Module (v2.0.0)
    │       │
    │       └─── Uses Azure Modules (v1.0.0)
    │               ├── networking
    │               ├── compute
    │               ├── aks
    │               ├── application-gateway
    │               ├── database
    │               ├── keyvault
    │               ├── sftp
    │               └── vpn-gateway
    │
    └─── Environment Configs (tfvars)
            ├── environments/em/{env}.tfvars
            ├── environments/baml/{env}.tfvars
            └── environments/em_nextgen/{env}.tfvars
```

## Versioning Scheme

We follow [Semantic Versioning 2.0.0](https://semver.org/):

**Format:** `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes, major architectural changes
- **MINOR**: New features, backward compatible additions
- **PATCH**: Bug fixes, documentation updates, non-breaking changes

## Module Versions

### 1. Azure Base Modules (`modules/azure/`)

**Current Version:** `1.0.0`

**Purpose:** Low-level Azure resource modules

**Version File:** `modules/azure/VERSION`

**Changelog:** `modules/azure/CHANGELOG.md`

**Modules Included:**
- `aks/` - Azure Kubernetes Service
- `application-gateway/` - Application Gateway with WAF
- `compute/` - Virtual Machines
- `db/` - Database resources
- `keyvault/` - Azure Key Vault
- `nat-gateway/` - NAT Gateway
- `networking/` - VNet, Subnets, NSG
- `rg/` - Resource Groups
- `sftp/` - SFTP Storage Accounts
- `storage-scripts/` - Storage account utilities
- `vnet-peering/` - VNet Peering
- `vpn-gateway/` - VPN Gateway

**When to Update:**
- **1.0.x**: Bug fixes in individual modules
- **1.x.0**: Add new Azure resources or features
- **x.0.0**: Breaking API changes in modules

### 2. EM Module (`modules/em/`)

**Current Version:** `2.0.0`

**Purpose:** High-level composition module for EM-specific patterns

**Version File:** `modules/em/VERSION`

**Changelog:** `modules/em/CHANGELOG.md`

**Dependencies:**
- Azure Modules: `1.0.0`
- Terraform: `>= 1.5.0`
- AzureRM Provider: `~> 3.0`

**When to Update:**
- **2.0.x**: Configuration updates, bug fixes
- **2.x.0**: New EM features, new deployment patterns
- **x.0.0**: Major architectural changes

### 3. Root Configuration (`main.tf`)

**Version Tracking:** Embedded in `main.tf` locals block

**Purpose:** Environment-specific deployments

**Version References:**
```hcl
locals {
  em_module_version = "2.0.0"
  azure_modules_version     = "1.0.0"
}
```

## Version Compatibility Matrix

| EM Infrastructure | Azure Modules | Terraform | AzureRM Provider | Status |
|-------------------|---------------|-----------|------------------|--------|
| 2.0.0             | 1.0.0         | >= 1.5.0  | ~> 3.0           | ✅ Current |
| 1.x.x             | 1.0.0         | >= 1.5.0  | ~> 3.0           | ⚠️ Legacy |

## Best Practices

### 1. Version Pinning

**Recommendation:** Pin versions in production environments

```hcl
# In environments/baml/prod.tfvars
# Add version constraints as variables

module_version_constraints = {
  em_infrastructure = "2.0.0"
  azure_modules     = "1.0.0"
}
```

### 2. Version Updates

**Process:**

1. **Development Environment**
   ```bash
   # Test new version in dev first
   ./scripts/deploy.sh baml dev plan
   ./scripts/deploy.sh baml dev apply
   ```

2. **Validation**
   - Run integration tests
   - Verify all resources created successfully
   - Check outputs and functionality

3. **Staging/CS Environment**
   ```bash
   # Deploy to staging
   ./scripts/deploy.sh baml cs plan
   ./scripts/deploy.sh baml cs apply
   ```

4. **Production Environment**
   ```bash
   # After approval, deploy to prod
   ./scripts/deploy.sh baml prod plan
   ./scripts/deploy.sh baml prod apply
   ```

### 3. Changelog Maintenance

Always update the appropriate CHANGELOG.md when making changes:

```bash
# Azure module change
vim modules/azure/CHANGELOG.md
echo "1.0.1" > modules/azure/VERSION

# EM module change
vim modules/em/CHANGELOG.md
echo "2.0.1" > modules/em/VERSION

# Root config change
vim terraform/main.tf  # Update version in locals
```

### 4. Git Tagging

Tag releases in Git for easy rollback:

```bash
# Tag a release
git tag -a v2.0.0 -m "EM Infrastructure v2.0.0 - Multi-product support"
git push origin v2.0.0

# View all tags
git tag -l
```

## Version Update Scenarios

### Scenario 1: Bug Fix in Azure Module

**Example:** Fix NSG rule in networking module

1. Make fix in `modules/azure/networking/`
2. Update `modules/azure/CHANGELOG.md`
3. Update `modules/azure/VERSION` → `1.0.1`
4. Optionally update `modules/em/VERSION` → `2.0.1`
5. Update `main.tf` locals with new versions
6. Test in dev environment
7. Deploy to higher environments

**Version Changes:**
- Azure Modules: `1.0.0` → `1.0.1`
- EM Infrastructure: `2.0.0` → `2.0.1` (optional)

### Scenario 2: Add New Azure Module

**Example:** Add Azure SQL Database module

1. Create `modules/azure/sql-database/`
2. Add module code
3. Update `modules/azure/CHANGELOG.md`
4. Update `modules/azure/VERSION` → `1.1.0`
5. Update EM infrastructure to use new module (if needed)
6. Update `modules/em/VERSION` → `2.1.0` (if using it)
7. Document in both CHANGELOGs

**Version Changes:**
- Azure Modules: `1.0.0` → `1.1.0`
- EM Infrastructure: `2.0.0` → `2.1.0` (if integrated)

### Scenario 3: Breaking Change

**Example:** Change networking module API

1. Update module with breaking change
2. Document breaking changes in CHANGELOG
3. Update `modules/azure/VERSION` → `2.0.0`
4. Update all references in EM infrastructure module
5. Update `modules/em/VERSION` → `3.0.0`
6. Create migration guide
7. Communicate to all teams
8. Test thoroughly before production

**Version Changes:**
- Azure Modules: `1.0.0` → `2.0.0`
- EM Infrastructure: `2.0.0` → `3.0.0`

### Scenario 4: New EM Feature

**Example:** Add Azure Front Door integration

1. Add Front Door resources using Azure modules
2. Update `modules/em/` with new feature
3. Update `modules/em/CHANGELOG.md`
4. Update `modules/em/VERSION` → `2.1.0`
5. Add feature flag in variables
6. Document usage
7. Test in dev environment

**Version Changes:**
- Azure Modules: `1.0.0` (unchanged)
- EM Infrastructure: `2.0.0` → `2.1.0`

## Rollback Strategy

### Rolling Back to Previous Version

1. **Identify Target Version**
   ```bash
   git tag -l
   # Example: v2.0.0
   ```

2. **Checkout Previous Version**
   ```bash
   git checkout v2.0.0
   ```

3. **Verify Version Files**
   ```bash
   cat modules/azure/VERSION
   cat modules/em/VERSION
   ```

4. **Deploy Previous Version**
   ```bash
   terraform init -upgrade
   terraform plan -var-file="environments/baml/prod.tfvars"
   terraform apply -var-file="environments/baml/prod.tfvars"
   ```

5. **Return to Latest**
   ```bash
   git checkout master
   ```

## Version Validation Script

Create a script to validate version consistency:

```bash
#!/bin/bash
# scripts/validate-versions.sh

echo "Checking module versions..."

AZURE_VERSION=$(cat modules/azure/VERSION)
EM_VERSION=$(cat modules/em/VERSION)
MAIN_AZURE=$(grep 'azure_modules_version.*=' main.tf | sed 's/.*"\(.*\)".*/\1/')
MAIN_EM=$(grep 'em_module_version.*=' main.tf | sed 's/.*"\(.*\)".*/\1/')

echo "Azure Modules:"
echo "  File: $AZURE_VERSION"
echo "  main.tf: $MAIN_AZURE"

echo "EM Infrastructure:"
echo "  File: $EM_VERSION"
echo "  main.tf: $MAIN_EM"

if [ "$AZURE_VERSION" != "$MAIN_AZURE" ]; then
    echo "⚠️  WARNING: Azure module version mismatch!"
fi

if [ "$EM_VERSION" != "$MAIN_EM" ]; then
    echo "⚠️  WARNING: EM module version mismatch!"
fi
```

## CI/CD Integration

### Pipeline Version Checks

Add to `azure-pipelines.yml`:

```yaml
- task: Bash@3
  displayName: 'Validate Module Versions'
  inputs:
    targetType: 'inline'
    script: |
      echo "Checking module version consistency..."
      ./scripts/validate-versions.sh
```

### Automated Changelog

Use conventional commits to auto-generate changelog:

```bash
# Commit format
git commit -m "feat(azure/networking): add support for IPv6"
git commit -m "fix(em): correct subnet calculation"
git commit -m "docs: update versioning strategy"
```

## Support and Questions

For versioning questions:
1. Check this document
2. Review module CHANGELOG.md files
3. Contact CloudOps team

## References

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Terraform Module Best Practices](https://www.terraform.io/docs/modules/index.html)
