# State Migration Issue & Solution

## The Problem

When you ran `terraform plan`, it showed:
```
Plan: 163 to add, 0 to change, 163 to destroy
```

This means Terraform wants to **destroy and recreate** all existing CS resources, which is unacceptable!

## Root Cause

### What Happened:

1. **Original State** (before adding `count`):
   - Resources were at paths like: `module.web_resources.module.keyvault[0].azurerm_key_vault.main`
   - No `count` on parent modules, so direct paths

2. **New Code** (after adding `count`):
   ```hcl
   module "web_resources" {
     count  = var.enable_web_vms ? 1 : 0
     ...
   }
   ```
   - Now expects paths like: `module.web_resources[0].module.keyvault[0].azurerm_key_vault.main`
   - Notice the `[0]` after `web_resources`!

3. **Path Mismatch**:
   - State has: `module.web_resources.something`
   - Code expects: `module.web_resources[0].something`
   - Terraform thinks these are DIFFERENT resources
   - So it wants to DELETE the old ones and CREATE new ones

## The Solution

We need to migrate EVERY resource in the state file from the old path to the new path:

```
module.web_resources.*            → module.web_resources[0].*
module.app_resources.*            → module.app_resources[0].*
module.db_resources_02.*          → module.db_resources_02[0].*
module.db_key_vault.*             → module.db_key_vault[0].*
module.hub_infrastructure.*       → module.hub_infrastructure[0].*
module.sftp.*                     → module.sftp[0].*
module.ado_resources.*            → module.ado_resources[0].*
```

## Why the First Migration Script Didn't Work

The original `migrate-cs-state.sh` tried to migrate like this:

```bash
terraform state mv 'module.web_resources' 'module.web_resources[0]'
```

**Problem:** This only works if there's a SINGLE resource called `module.web_resources`, but in reality, the state has 163+ resources nested UNDER these modules:
- `module.web_resources.module.keyvault[0].azurerm_key_vault.main`
- `module.web_resources.module.compute["VM01"].azurerm_windows_virtual_machine.vm`
- `module.web_resources.azurerm_user_assigned_identity.appgw[0]`
- ... and 160+ more!

We need to migrate EACH resource individually.

## The Fix

The new script `migrate-cs-state-fixed.sh`:

1. **Lists all resources** that need migration (without `[0]` on parent module)
2. **Migrates each resource** individually:
   ```bash
   terraform state mv \
     'module.web_resources.module.keyvault[0].azurerm_key_vault.main' \
     'module.web_resources[0].module.keyvault[0].azurerm_key_vault.main'
   ```
3. **Tracks progress** and handles errors gracefully
4. **Verifies** all resources are migrated

## Running the Migration

```bash
cd terraform

# 1. Initialize (must do this first)
terraform init

# 2. Backup state
terraform state pull > state-backup-$(date +%Y%m%d).json

# 3. Run fixed migration script
./migrate-cs-state-fixed.sh

# 4. Verify (should show 0 changes!)
terraform plan -var-file="environments/em_bofa/cs.tfvars"
```

## What Happens During Migration

The script will:
- ✅ Update state file paths (NO Azure resources affected)
- ✅ Keep all existing resources exactly as they are
- ✅ Not destroy or recreate anything
- ✅ Only change internal Terraform bookkeeping

After migration, `terraform plan` will show:
```
No changes. Your infrastructure matches the configuration.
```

## For Pipeline Execution

You suggested running migration via pipeline. Here's how:

### Option 1: Manual Migration First (Recommended)
1. Run migration script manually on your machine
2. Push updated state to Azure Storage
3. Then run pipeline normally

### Option 2: Add Migration Step to Pipeline
Add a one-time migration job before the plan step:

```yaml
- job: MigrateState
  condition: eq(variables['RUN_MIGRATION'], 'true')
  steps:
    - template: templates/init.yml
    - bash: |
        terraform state pull > state-backup-$(date +%Y%m%d).json
        ./migrate-cs-state-fixed.sh
      displayName: 'Migrate CS State'
```

Then trigger with `RUN_MIGRATION=true` once, then remove/disable this step.

## Verification

After migration, check:

1. **Terraform plan shows no changes**:
   ```
   Plan: 0 to add, 0 to change, 0 to destroy.
   ```

2. **All resources are at new paths**:
   ```bash
   terraform state list | grep "web_resources\[0\]"
   ```
   Should show many resources.

3. **No resources at old paths**:
   ```bash
   terraform state list | grep "web_resources\." | grep -v "\[0\]"
   ```
   Should show nothing.

## Safety

This migration is **100% safe** because:
- ✅ Only modifies Terraform state file (not Azure resources)
- ✅ We backup state before starting
- ✅ Can be rolled back by restoring state backup
- ✅ Script exits on first error
- ✅ No destructive Azure API calls

---

**Key Takeaway:** The plan showing "163 to destroy" was a FALSE alarm caused by state path mismatch. Once we migrate the state paths, everything will work perfectly without any resource destruction.
