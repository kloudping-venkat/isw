# Quick Start: Pipeline Migration

## TL;DR - What To Do

### 1️⃣ Commit & Push (Now)
```bash
git add -A
git commit -m "Add temporary state migration step"
git push origin isw-301-walmart
```

### 2️⃣ Run Pipeline (Azure DevOps)
**Pipeline**: `multi-env-pipeline`

**Settings**:
- Product: `em_bofa`
- Environment: `cs`
- Action: `plan-only`
- **Run State Migration: `TRUE`** ⬅️ This is the key!

### 3️⃣ Verify Success
Look for these in pipeline output:
```
✅ Migration Complete! Migrated 163 resources successfully
✅ VERIFICATION PASSED! Plan shows: 0 to add, 0 to change, 0 to destroy
```

### 4️⃣ Remove Migration Code (After Success)
Edit `pipelines/multi-env-pipeline.yml`:
- Delete lines ~96-101 (runStateMigration parameter)
- Delete lines ~178-185 (migrate-state template call)

```bash
git add pipelines/multi-env-pipeline.yml
git commit -m "Remove temporary migration step - migration complete"
git push origin isw-301-walmart
```

### 5️⃣ Done! 🎉
Now you can:
- Deploy Walmart: Set environment to `walmart`, action to `plan-and-apply`
- Update CS normally: Everything works as before

---

## Files Changed

**Added** (temporary - keep for now):
- ✅ `pipelines/templates/migrate-state.yml` - Migration logic
- ✅ `pipelines/multi-env-pipeline.yml` - Added parameter & step

**Added** (keep forever):
- ✅ `terraform/migrate-cs-state-fixed.sh` - Manual migration script (backup)
- ✅ `terraform/FLAG-APPROACH-GUIDE.md` - How flag approach works
- ✅ `terraform/STATE-MIGRATION-EXPLANATION.md` - Why migration needed
- ✅ `terraform/PIPELINE-MIGRATION-GUIDE.md` - Detailed guide
- ✅ `terraform/MIGRATION-QUICK-START.md` - This file!

**To Remove Later** (after migration succeeds):
- ❌ Parameter in `multi-env-pipeline.yml` (lines ~96-101)
- ❌ Step in `multi-env-pipeline.yml` (lines ~178-185)
- ❌ Optionally: `pipelines/templates/migrate-state.yml`

---

## What Gets Migrated

All CS resources (163 total):
```
module.web_resources.*            → module.web_resources[0].*
module.app_resources.*            → module.app_resources[0].*
module.db_resources_02.*          → module.db_resources_02[0].*
module.db_key_vault.*             → module.db_key_vault[0].*
module.hub_infrastructure.*       → module.hub_infrastructure[0].*
module.sftp.*                     → module.sftp[0].*
module.ado_resources.*            → module.ado_resources[0].*
```

**Important**: This only changes Terraform's internal bookkeeping. No Azure resources are touched!

---

## Troubleshooting

### Pipeline shows "Error: Failed to migrate"
- Check which resource failed in the logs
- State backup is created automatically in `state-backups/` directory
- **Can restore from backup** - See below

### Verification shows changes (not 0)
- Migration incomplete
- DO NOT run apply
- Restore from backup and investigate

### Can't find the parameter
- Make sure you pushed the code changes
- Use the updated `multi-env-pipeline.yml`
- Parameter should appear in the UI

### 🚨 Need to Restore from Backup?

If migration fails, you can restore via pipeline:

**Run pipeline with**:
```
Restore State from Backup:  ✅ TRUE
Backup File Path:           state-backups/state-backup-YYYYMMDD-HHMMSS.json
```

**See**: `RESTORE-FROM-BACKUP.md` for complete guide

---

## Safety Checklist

Before running migration:
- ✅ Code is committed and pushed
- ✅ Using `plan-only` action (not apply)
- ✅ Environment is set to `cs`
- ✅ Team is aware migration is happening

After migration:
- ✅ Verification passed (0 changes)
- ✅ Final plan shows 0 changes
- ✅ Tested Walmart deployment (optional)
- ✅ Removed migration code from pipeline
- ✅ Pushed cleanup commit

---

**Need more details?** See `PIPELINE-MIGRATION-GUIDE.md` for full documentation.
