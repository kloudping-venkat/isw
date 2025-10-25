# Pipeline State Migration Guide

This guide shows how to run the one-time CS state migration via Azure DevOps pipeline, then remove the migration step.

## Overview

The migration step has been added as a **temporary, conditional parameter** in the multi-env pipeline:
- ✅ Only runs when you explicitly enable it
- ✅ Disabled by default (safe)
- ✅ Can be easily removed after migration completes
- ✅ Includes automatic verification

## Step 1: Commit and Push Migration Changes

First, commit all the migration-related files:

```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC

git add terraform/pipelines/templates/migrate-state.yml
git add pipelines/templates/migrate-state.yml
git add pipelines/multi-env-pipeline.yml
git add terraform/migrate-cs-state-fixed.sh
git add terraform/STATE-MIGRATION-EXPLANATION.md
git add terraform/PIPELINE-MIGRATION-GUIDE.md
git add terraform/FLAG-APPROACH-GUIDE.md

git commit -m "Add temporary state migration step to pipeline

- Added migrate-state.yml template with backup and verification
- Added runStateMigration parameter to multi-env-pipeline.yml
- Migration step is disabled by default
- Includes comprehensive error handling and verification
- Will be removed after one-time CS migration completes

Related to: ISW-301 Walmart infrastructure setup"

git push origin isw-301-walmart
```

## Step 2: Run Migration via Pipeline

### In Azure DevOps:

1. **Navigate to Pipeline**:
   - Go to Pipelines → `multi-env-pipeline`
   - Click "Run pipeline"

2. **Configure Pipeline Parameters**:
   ```
   Product/Client:           em_bofa
   Environment:              cs
   Terraform Version:        latest
   Terraform Action:         plan-only  ⚠️ IMPORTANT: Use plan-only first!
   Refresh Terraform State:  false
   Import Resources:         false
   Remove from State:        false
   Force Unlock:             false
   Run State Migration:      ✅ TRUE    ⚠️ THIS IS THE KEY PARAMETER!
   ```

3. **Start the Pipeline**:
   - Click "Run"
   - Monitor the pipeline execution

### What Happens:

The pipeline will execute in this order:

1. **Initialize Terraform**
   - Sets up backend and downloads providers

2. **Validate Configuration**
   - Ensures Terraform config is valid

3. **🔧 Run State Migration** (your new step!)
   - **Backup State**: Creates timestamped backup in `state-backups/` directory
   - **Migrate Resources**: Moves all 163+ resources from `module.X.*` to `module.X[0].*`
   - **Verify Migration**: Runs `terraform plan` to confirm 0 changes

4. **Terraform Plan**
   - Final plan should show: **0 to add, 0 to change, 0 to destroy** ✅

## Step 3: Review Migration Results

### Success Indicators:

✅ **Migration step shows**:
```
✅ Migration Complete!
Migrated 163 resources successfully
```

✅ **Verification step shows**:
```
✅ VERIFICATION PASSED!
Plan shows: 0 to add, 0 to change, 0 to destroy
Migration was successful!
```

✅ **Final plan step shows**:
```
No changes. Your infrastructure matches the configuration.
```

### If Migration Fails:

❌ **Error in migration step**:
- Check which resource failed to migrate
- Pipeline will stop immediately
- State backup is available in `state-backups/` directory
- Contact DevOps team for manual state restoration

❌ **Verification shows changes**:
- Migration may be incomplete
- DO NOT proceed with apply
- Review the plan output to see what's different
- May need to run migration again

## Step 4: Test Walmart Deployment (Optional)

After CS migration succeeds, test Walmart deployment:

1. **Run Pipeline Again**:
   ```
   Product/Client:           em_bofa
   Environment:              walmart
   Terraform Action:         plan-only
   Run State Migration:      ❌ FALSE  (not needed for Walmart)
   ```

2. **Expected Result**:
   - Should show creation of Walmart spoke network
   - Should show VNet peering to CS hub
   - Should NOT show any CS resources

## Step 5: Remove Migration Step from Pipeline

Once migration is confirmed successful, remove the temporary migration code:

### A. Edit `pipelines/multi-env-pipeline.yml`

**Remove the parameter** (lines ~96-101):
```yaml
# DELETE THESE LINES:
  # ⚠️ TEMPORARY: One-time state migration for CS environment
  # TODO: REMOVE THIS PARAMETER AFTER MIGRATION IS COMPLETE
  - name: runStateMigration
    displayName: '🔧 Run State Migration (CS only - ONE TIME use, then remove this step)'
    type: boolean
    default: false
```

**Remove the step** (lines ~178-185):
```yaml
# DELETE THESE LINES:
          # ⚠️ TEMPORARY: State Migration for CS Environment
          # TODO: REMOVE THIS STEP AFTER MIGRATION IS COMPLETE
          - ${{ if eq(parameters.runStateMigration, true) }}:
            - template: templates/migrate-state.yml
              parameters:
                environment: ${{ parameters.environment }}
                workingDirectory: $(workingDirectory)
                tfVarsFile: $(tfVarsFile)
```

### B. Optional: Keep Migration Template for Reference

You can choose to:

**Option 1**: Delete the template (clean approach)
```bash
git rm pipelines/templates/migrate-state.yml
```

**Option 2**: Keep it for future reference (recommended)
```bash
# Just remove it from being called in the pipeline
# Keep the file in git history for future migrations
```

### C. Commit Cleanup

```bash
git add pipelines/multi-env-pipeline.yml
# And optionally: git rm pipelines/templates/migrate-state.yml

git commit -m "Remove temporary state migration step

Migration completed successfully for CS environment.
Removed runStateMigration parameter and migrate-state template call.

CS state is now at correct paths with [0] indexing.
Walmart deployment is ready to proceed."

git push origin isw-301-walmart
```

## Step 6: Proceed with Normal Operations

After cleanup, the pipeline is back to normal:

### Deploy Walmart (Networking Only):
```
Product/Client:      em_bofa
Environment:         walmart
Terraform Action:    plan-and-apply
```

### Future CS Updates:
```
Product/Client:      em_bofa
Environment:         cs
Terraform Action:    plan-and-apply
```

Everything works normally now! 🎉

## Rollback Plan (If Needed)

If migration fails and you need to restore:

### Via Azure Portal:
1. Go to Storage Account: `stcertentterraform47486`
2. Container: `terraform-state-rg-terraform-cs`
3. Blob: `cs.terraform.tfstate`
4. Find backup in `state-backups/` directory
5. Restore from backup

### Via Pipeline:
You could create a restore script if needed (not included in this implementation).

## Summary

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Commit & push migration code | Code ready in repo |
| 2 | Run pipeline with `runStateMigration=true` | Migration completes, 0 changes in plan |
| 3 | Review results | All green checkmarks ✅ |
| 4 | Test Walmart (optional) | Walmart spoke deploys successfully |
| 5 | Remove migration code | Pipeline cleaned up |
| 6 | Normal operations | Both CS and Walmart work perfectly |

---

**Key Points**:
- ✅ Migration only runs when explicitly enabled
- ✅ Automatic backup before migration
- ✅ Automatic verification after migration
- ✅ Easy to remove after completion
- ✅ Safe to run (only modifies state, not resources)
- ✅ Pipeline stops immediately on any error

**Timeline**:
- Migration run: ~10-15 minutes (depending on number of resources)
- One-time operation
- Remove code same day after verification
