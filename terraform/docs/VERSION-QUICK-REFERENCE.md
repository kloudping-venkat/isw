# Module Versioning - Quick Reference

## Current Versions

| Module | Version | Location | Status |
|--------|---------|----------|--------|
| **Azure Base Modules** | 1.0.0 | `modules/azure/` | ✅ Stable |
| **EM Infrastructure** | 2.0.0 | `modules/em/` | ✅ Stable |

## Quick Commands

### Check Versions
```bash
# Validate all versions are consistent
./scripts/validate-versions.sh

# Check Azure modules version
cat modules/azure/VERSION

# Check EM infrastructure version
cat modules/em/VERSION
```

### Update Version - Azure Modules

```bash
# 1. Make your changes to Azure modules
# 2. Update VERSION file
echo "1.0.1" > modules/azure/VERSION

# 3. Update CHANGELOG
vim modules/azure/CHANGELOG.md

# 4. Update main.tf
vim main.tf  # Update azure_modules_version in locals

# 5. Validate
./scripts/validate-versions.sh

# 6. Commit
git add .
git commit -m "chore: bump Azure modules to 1.0.1"
git tag -a azure-v1.0.1 -m "Azure modules v1.0.1"
```

### Update Version - EM Infrastructure

```bash
# 1. Make your changes to EM infrastructure
# 2. Update VERSION file
echo "2.0.1" > modules/em/VERSION

# 3. Update CHANGELOG
vim modules/em/CHANGELOG.md

# 4. Update main.tf
vim main.tf  # Update em_module_version in locals

# 5. Validate
./scripts/validate-versions.sh

# 6. Commit
git add .
git commit -m "feat: add new EM feature"
git tag -a em-v2.0.1 -m "EM Infrastructure v2.0.1"
```

## Version Decision Tree

```
Do you need to make a change?
│
├─ YES → What kind of change?
│        │
│        ├─ Bug fix in Azure module → Azure: X.Y.Z+1 (patch)
│        ├─ New Azure resource type → Azure: X.Y+1.0 (minor)
│        ├─ Breaking change in Azure → Azure: X+1.0.0 (major)
│        │                             EM: X+1.0.0 (major)
│        │
│        ├─ New EM feature → EM: X.Y+1.0 (minor)
│        ├─ EM bug fix → EM: X.Y.Z+1 (patch)
│        └─ Breaking EM change → EM: X+1.0.0 (major)
│
└─ NO → Keep current versions
```

## Semantic Versioning Examples

### PATCH (0.0.X) - Bug Fixes
```
Examples:
- Fix NSG rule typo
- Correct subnet calculation
- Update documentation
- Fix variable default value

Before: 1.0.0
After:  1.0.1
```

### MINOR (0.X.0) - New Features
```
Examples:
- Add new Azure module (e.g., Azure SQL)
- Add new optional parameter
- Add new output
- Add new EM deployment pattern

Before: 1.0.0
After:  1.1.0
```

### MAJOR (X.0.0) - Breaking Changes
```
Examples:
- Change required variable name
- Remove deprecated parameter
- Change module directory structure
- Change output format
- Require new Terraform version

Before: 1.0.0
After:  2.0.0
```

## Deployment Workflow with Versions

### 1. Development
```bash
# Work on feature branch
git checkout -b feature/new-azure-module

# Make changes, update versions
echo "1.1.0" > modules/azure/VERSION

# Test locally
./scripts/deploy.sh baml dev plan
./scripts/deploy.sh baml dev apply

# Validate versions
./scripts/validate-versions.sh
```

### 2. Testing
```bash
# Merge to develop branch
git checkout develop
git merge feature/new-azure-module

# Deploy to CS (staging)
./scripts/deploy.sh baml cs apply
```

### 3. Production
```bash
# Merge to master
git checkout master
git merge develop

# Tag release
git tag -a v1.1.0 -m "Release v1.1.0 - Add Azure SQL module"
git push origin v1.1.0

# Deploy to production
./scripts/deploy.sh baml prod apply
```

## Version Compatibility

### Supported Combinations

| Env Type | EM Version | Azure Version | Testing Required |
|----------|------------|---------------|------------------|
| Dev | latest | latest | ✅ Always test first |
| CS/Staging | stable | stable | ✅ Before prod |
| Prod | stable | stable | ✅ Full validation |

### Upgrade Path

```
Current: EM 2.0.0 + Azure 1.0.0
    ↓
Step 1: EM 2.0.0 + Azure 1.1.0  (Update Azure modules)
    ↓
Step 2: EM 2.1.0 + Azure 1.1.0  (Update EM to use new features)
    ↓
Production: EM 2.1.0 + Azure 1.1.0
```

## CI/CD Integration

### Add to Pipeline

```yaml
# azure-pipelines.yml
- stage: ValidateVersions
  jobs:
    - job: CheckVersions
      steps:
        - task: Bash@3
          displayName: 'Validate Module Versions'
          inputs:
            filePath: 'terraform/scripts/validate-versions.sh'
```

## Troubleshooting

### Version Mismatch Error
```bash
# Problem: validate-versions.sh reports mismatch

# Solution 1: Update VERSION file
echo "2.0.0" > modules/em/VERSION

# Solution 2: Update main.tf
# Edit locals block to match VERSION files

# Verify
./scripts/validate-versions.sh
```

### Rollback to Previous Version
```bash
# Find available versions
git tag -l

# Checkout specific version
git checkout v2.0.0

# Deploy
./scripts/deploy.sh baml prod apply
```

## Cheat Sheet

| Task | Command |
|------|---------|
| Check current versions | `./scripts/validate-versions.sh` |
| View Azure version | `cat modules/azure/VERSION` |
| View EM version | `cat modules/em/VERSION` |
| Update Azure version | `echo "X.Y.Z" > modules/azure/VERSION` |
| Update EM version | `echo "X.Y.Z" > modules/em/VERSION` |
| List all version tags | `git tag -l` |
| Create version tag | `git tag -a vX.Y.Z -m "Message"` |
| Deploy specific version | `git checkout vX.Y.Z && ./scripts/deploy.sh ...` |

## Need Help?

1. Check `docs/VERSIONING-STRATEGY.md` for detailed information
2. Review module CHANGELOG.md files
3. Contact CloudOps team

## References

- Detailed Strategy: `docs/VERSIONING-STRATEGY.md`
- Azure Modules Changelog: `modules/azure/CHANGELOG.md`
- EM Infrastructure Changelog: `modules/em/CHANGELOG.md`
- Deployment Guide: `DEPLOYMENT-GUIDE.md`
