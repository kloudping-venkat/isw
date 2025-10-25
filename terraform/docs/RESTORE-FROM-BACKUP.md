# Restore State from Backup

## When to Use This

Use state restoration if:
- ❌ Migration failed and left state in bad condition
- ❌ Accidental changes were made to state
- ❌ Need to rollback to a previous state version
- ❌ State corruption occurred

## ⚠️ Important Notes

**DO NOT use restore unless**:
- You've confirmed migration failed
- You have a valid backup file
- You understand this will overwrite current state
- You've consulted with the team

**This is an emergency feature** - normal operations should never need it.

---

## Option 1: Restore via Pipeline (Recommended)

### Step 1: Get Backup File Path

After migration runs, the backup is created at:
```
state-backups/state-backup-YYYYMMDD-HHMMSS.json
```

Example: `state-backups/state-backup-20241015-142530.json`

You can find this in the migration pipeline logs under "Backup Terraform State" step.

### Step 2: Run Restore Pipeline

**Navigate to**: Pipelines → `multi-env-pipeline` → Run pipeline

**Configure**:
```
Product/Client:              em_bofa
Environment:                 cs
Terraform Version:           latest
Terraform Action:            plan-only
Refresh Terraform State:     false
Import Resources:            false
Remove from State:           false
Force Unlock:                false
Run State Migration:         false
Restore State from Backup:   ✅ TRUE
Backup File Path:            state-backups/state-backup-20241015-142530.json
```

**Click**: Run

### Step 3: Verify Restoration

The pipeline will:
1. ✅ Backup current state (safety measure)
2. ✅ Restore from specified backup
3. ✅ Verify restoration succeeded
4. ✅ Show resource count

Look for:
```
✅ State Restored Successfully!
State contains 163 resources
```

---

## Option 2: Restore Manually

If you have the backup file locally:

### Step 1: Download Backup

If backup is in Azure Storage (from previous pipeline run):
1. Go to Storage Account: `stcertentterraform47486`
2. Container: `terraform-state-rg-terraform-cs` (for CS) or `tfstate` (for others)
3. Download the backup file from `state-backups/` directory

### Step 2: Initialize Terraform

```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC/terraform

# Initialize with Azure backend
terraform init
```

### Step 3: Backup Current State (Safety)

```bash
# Just in case you need to restore to "current" later
terraform state pull > current-state-before-restore-$(date +%Y%m%d-%H%M%S).json
```

### Step 4: Restore from Backup

```bash
# Replace with your actual backup file path
BACKUP_FILE="state-backup-20241015-142530.json"

# Push backup to remote state
terraform state push "$BACKUP_FILE"
```

### Step 5: Verify

```bash
# Check resource count
terraform state list | wc -l

# Should show 163 resources for CS

# Run plan to verify
terraform plan -var-file="environments/em_bofa/cs.tfvars"
```

---

## Option 3: Restore via Azure Portal

If backups are stored in Azure Storage:

### Step 1: Access Storage Account

1. Go to Azure Portal
2. Navigate to: `stcertentterraform47486`
3. Go to: Containers → `terraform-state-rg-terraform-cs`
4. Find blob: `cs.terraform.tfstate`

### Step 2: View Blob Versions

Azure Storage has blob versioning enabled (if configured):
1. Click on `cs.terraform.tfstate`
2. Click "Versions" tab
3. Find the version from before migration
4. Click "Make current version"

### Step 3: Verify in Terraform

```bash
cd terraform
terraform init
terraform plan -var-file="environments/em_bofa/cs.tfvars"
```

---

## Verification After Restore

After restoring state, verify:

### 1. Resource Count
```bash
terraform state list | wc -l
# Should show: 163 (for CS environment)
```

### 2. Sample Resources
```bash
terraform state list | grep "web_resources"
# Should show resources WITHOUT [0] if restored to pre-migration state
# Should show resources WITH [0] if restored to post-migration state
```

### 3. Terraform Plan
```bash
terraform plan -var-file="environments/em_bofa/cs.tfvars"
# Should match expectations based on which backup you restored
```

---

## Common Scenarios

### Scenario 1: Migration Failed Partway Through

**Problem**: Migration script crashed after migrating 50 out of 163 resources.

**Solution**:
1. Restore from backup taken before migration started
2. Fix the issue that caused the crash
3. Re-run migration

**Steps**:
```bash
# Via pipeline:
- Restore State from Backup: TRUE
- Backup File Path: state-backups/state-backup-20241015-142530.json
```

### Scenario 2: Migration Succeeded but Broke Something

**Problem**: Migration completed but something is wrong.

**Solution**:
1. Restore from pre-migration backup
2. Investigate what went wrong
3. Decide whether to retry migration or use different approach

### Scenario 3: Accidentally Modified State

**Problem**: Someone manually edited state or ran wrong command.

**Solution**:
1. Find the most recent backup before the change
2. Restore from that backup
3. Run plan to verify

---

## Backup File Naming Convention

Pipeline creates backups with this format:
```
state-backups/state-backup-YYYYMMDD-HHMMSS.json
```

Examples:
- `state-backup-20241015-142530.json` - October 15, 2024 at 14:25:30
- `state-backup-20241015-153045.json` - October 15, 2024 at 15:30:45

The timestamp helps you identify when the backup was created.

---

## Safety Features

When restoring via pipeline:
- ✅ Current state is backed up before restoration (double safety)
- ✅ Verification step confirms restoration succeeded
- ✅ Shows resource count to detect if backup is corrupt
- ✅ Fails immediately if backup file doesn't exist

When restoring manually:
- ✅ You create safety backup first
- ✅ You can verify before pushing to remote
- ✅ You control the entire process

---

## Troubleshooting

### "Backup file not found"

**Cause**: Backup file path is wrong or doesn't exist

**Fix**:
1. Check pipeline logs for actual backup file name
2. Look in `state-backups/` directory
3. Verify path is relative to working directory

### "State appears empty after restore"

**Cause**: Backup file might be corrupt or empty

**Fix**:
1. Check backup file size (should be ~100KB+ for CS)
2. Open backup file and verify it's valid JSON
3. Try a different backup file

### "Restore succeeded but plan shows changes"

**Cause**: You restored to a different version than expected

**Fix**:
1. Check which backup you restored
2. Verify it's the correct one for your situation
3. If wrong, restore again with correct backup

---

## After Successful Restore

Once state is restored:

1. **If restoring pre-migration state**:
   - State is back to original paths (no `[0]`)
   - You can re-attempt migration after fixing issues
   - Or decide on different approach

2. **If restoring post-migration state**:
   - State has `[0]` indexing
   - Migration is complete
   - Proceed with normal operations

3. **Document what happened**:
   - Why restoration was needed
   - Which backup was used
   - What was learned

---

## Prevention

To avoid needing restoration:

- ✅ Always run migrations in `plan-only` mode first
- ✅ Verify backups are created before changes
- ✅ Test on non-production environment first (if possible)
- ✅ Have team review migration plan before execution
- ✅ Monitor pipeline execution closely
- ✅ Keep multiple backup copies

---

## Emergency Contact

If restore fails or you're unsure:
1. Don't panic - you have multiple backup layers
2. Stop any running pipelines
3. Contact DevOps team
4. Have backup file path ready
5. Explain what happened

**Remember**: State restoration is safe - it only changes Terraform's bookkeeping, not actual Azure resources.
