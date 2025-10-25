# Migration Troubleshooting Guide

## Issue: Verification Failed - "133 to add, 133 to destroy"

This means the migration **partially completed** but didn't finish all resources.

### What Happened

The migration script started moving resources but didn't catch all of them due to a regex pattern issue. The state is now in a **partially migrated** state:
- ✅ Some resources at `module.X[0].*` (migrated)
- ❌ Some resources still at `module.X.*` (not migrated)

### Why It Happened

The original grep pattern was:
```bash
grep -E "^module\.(name)\." | grep -v "\[0\]"
```

This would match:
- ✅ `module.web_resources.something`
- ❌ But also `module.web_resources[0].something` (already migrated)

The second `grep -v "\[0\]"` was trying to filter out migrated resources, but it wasn't working correctly.

### The Fix

Updated pattern (already fixed in latest code):
```bash
grep -E "^module\.(name)\.[^[]"
```

This correctly matches:
- ✅ `module.web_resources.something` (needs migration - has DOT after name)
- ❌ `module.web_resources[0].something` (already migrated - has [0] after name)

## Solution Options

### Option 1: Complete the Migration (Recommended)

The state is partially migrated. We just need to finish migrating the remaining resources.

**Run the fix script**:
```bash
cd terraform

# Make sure terraform is initialized
terraform init

# Run the fix script
./fix-partial-migration.sh
```

This will:
1. Find remaining resources that need migration
2. Show you what's already migrated vs. what's left
3. Complete the migration
4. Verify with terraform plan

### Option 2: Restore from Backup

If you want to start over:

1. **Find the backup**: The pipeline should have created a backup in `state-backups/state-backup-TIMESTAMP.json`

2. **Restore manually**:
   ```bash
   # Push backup to Azure Storage
   az storage blob upload \
     --account-name stcertentterraform47486 \
     --container-name terraform-state-rg-terraform-cs \
     --name cs.terraform.tfstate \
     --file state-backups/state-backup-TIMESTAMP.json \
     --overwrite
   ```

3. **Run migration again** with fixed code:
   - Commit and push the updated `migrate-state.yml`
   - Run pipeline with `runStateMigration=true` again

### Option 3: Update Code and Re-run Pipeline

The migration template has been fixed. You can:

1. **Commit the fixes**:
   ```bash
   git add pipelines/templates/migrate-state.yml
   git add terraform/migrate-cs-state-fixed.sh
   git add terraform/fix-partial-migration.sh
   git commit -m "Fix migration grep pattern and add recovery script"
   git push origin isw-301-walmart
   ```

2. **Run the fix script manually** (Option 1 above)

   OR

3. **Re-run the pipeline**:
   - The fixed migration template will now detect the remaining unmigrated resources
   - It will complete the migration
   - Verification should pass

## Checking Current State

To see what's migrated and what's not:

```bash
cd terraform
terraform init

# Resources that still need migration (without [0])
terraform state list | grep -E "^module\.(hub_infrastructure|sftp|web_resources|app_resources|db_resources_02|db_key_vault|ado_resources)\.[^[]"

# Resources already migrated (with [0])
terraform state list | grep -E "^module\.(hub_infrastructure|sftp|web_resources|app_resources|db_resources_02|db_key_vault|ado_resources)\[0\]"
```

## Understanding the Error

**"133 to add, 133 to destroy"** means:

- **133 to destroy**: Resources at OLD paths `module.X.*` (Terraform thinks these are old)
- **133 to add**: Same resources at NEW paths `module.X[0].*` (Terraform thinks these are new)
- **3 to change**: A few resources that might have minor config differences

This is actually **good news** - it means:
- ✅ No actual Azure resources will be destroyed
- ✅ It's just a state path issue
- ✅ Easy to fix by completing the migration

## Prevention

The fixed grep pattern prevents this issue:

**Before** (buggy):
```bash
grep -E "^module\.name\." | grep -v "\[0\]"
# Problem: grep -v "\[0\]" filters lines containing [0] ANYWHERE
```

**After** (fixed):
```bash
grep -E "^module\.name\.[^[]"
# Solution: Explicitly match DOT after module name (not [0])
```

## Next Steps

**Recommended approach**:

1. Run `./fix-partial-migration.sh` to complete the migration
2. Verify with `terraform plan` → should show 0 changes
3. Continue with Walmart deployment

**Alternative**:

1. Restore from backup
2. Commit fixed migration code
3. Re-run pipeline with `runStateMigration=true`

---

**Need help?** Check the pipeline logs to see:
- How many resources were migrated before it stopped
- Which resource failed (if any)
- The state backup location
