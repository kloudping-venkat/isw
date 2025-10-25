# CS State Migration - Complete Package

## 📦 What's Included

This migration package includes everything you need to safely migrate CS environment state via Azure DevOps pipeline with automatic backup and restore capabilities.

### Pipeline Templates
- ✅ `pipelines/templates/migrate-state.yml` - Migration logic with backup & verification
- ✅ `pipelines/templates/restore-state.yml` - Restore from backup (emergency use)
- ✅ `pipelines/multi-env-pipeline.yml` - Updated with migration & restore parameters

### Scripts
- ✅ `migrate-cs-state-fixed.sh` - Manual migration script (backup option)
- ✅ `migrate-cs-state.sh` - Original script (reference)

### Documentation
- ✅ `MIGRATION-QUICK-START.md` - **START HERE** - Quick reference
- ✅ `PIPELINE-MIGRATION-GUIDE.md` - Complete step-by-step guide
- ✅ `STATE-MIGRATION-EXPLANATION.md` - Technical deep dive
- ✅ `FLAG-APPROACH-GUIDE.md` - How flag system works
- ✅ `RESTORE-FROM-BACKUP.md` - How to restore if needed
- ✅ `README-MIGRATION.md` - This file

---

## 🎯 Quick Reference

### Read These in Order:

1. **MIGRATION-QUICK-START.md** (5 min)
   - Quick reference card
   - Exactly what to do
   - No extra details

2. **PIPELINE-MIGRATION-GUIDE.md** (10 min)
   - Complete walkthrough
   - Every step explained
   - What to expect

3. **STATE-MIGRATION-EXPLANATION.md** (10 min)
   - Why migration is needed
   - What the problem was
   - How solution works

4. **FLAG-APPROACH-GUIDE.md** (5 min)
   - How enable flags work
   - CS vs Walmart configuration
   - Future deployments

5. **RESTORE-FROM-BACKUP.md** (reference)
   - Only read if migration fails
   - How to restore state
   - Multiple restore options

---

## 🚀 The 5-Minute Version

### What's the Problem?
Terraform plan shows "163 to destroy" because state paths changed when we added `count` to modules.

### What's the Solution?
Run migration via pipeline to update all state paths from `module.X.*` to `module.X[0].*`

### How Do I Do It?

**1. Commit & Push**:
```bash
git add -A
git commit -m "Add state migration to pipeline"
git push origin isw-301-walmart
```

**2. Run Pipeline**:
- Pipeline: `multi-env-pipeline`
- Environment: `cs`
- Action: `plan-only`
- **Run State Migration: `TRUE`**

**3. Verify Success**:
```
✅ Migration Complete! Migrated 163 resources
✅ VERIFICATION PASSED! Plan shows: 0 changes
```

**4. Remove Migration Code**:
Edit `pipelines/multi-env-pipeline.yml` and delete migration parameter & step.

**5. Done!**
Deploy Walmart or update CS normally.

---

## 📊 File Structure

```
EM.NextGen-IaC/
├── pipelines/
│   ├── multi-env-pipeline.yml          (✏️ Modified - added migration parameters)
│   └── templates/
│       ├── migrate-state.yml           (✨ New - migration logic)
│       └── restore-state.yml           (✨ New - restore logic)
│
└── terraform/
    ├── environments/
    │   └── em_bofa/
    │       ├── cs.tfvars                (✏️ Modified - enable flags added)
    │       └── walmart.tfvars           (✏️ Modified - enable flags added)
    │
    ├── migrate-cs-state-fixed.sh        (✨ New - manual migration)
    ├── migrate-cs-state.sh              (📁 Keep - original reference)
    │
    └── Documentation/
        ├── MIGRATION-QUICK-START.md     (✨ New - Quick reference)
        ├── PIPELINE-MIGRATION-GUIDE.md  (✨ New - Complete guide)
        ├── STATE-MIGRATION-EXPLANATION.md (✨ New - Technical details)
        ├── FLAG-APPROACH-GUIDE.md       (✨ New - How flags work)
        ├── RESTORE-FROM-BACKUP.md       (✨ New - Restore guide)
        └── README-MIGRATION.md          (✨ New - This file)
```

---

## 🛡️ Safety Features

### Before Migration
- ✅ Automatic state backup with timestamp
- ✅ Disabled by default (explicit opt-in required)
- ✅ Plan-only mode recommended

### During Migration
- ✅ Progress tracking (shows each resource)
- ✅ Immediate failure on error
- ✅ No Azure API calls (state-only changes)

### After Migration
- ✅ Automatic verification (must show 0 changes)
- ✅ Resource count validation
- ✅ Detailed success/failure reporting

### If Migration Fails
- ✅ Restore capability via pipeline
- ✅ Multiple backup copies
- ✅ Manual restore options
- ✅ Safety backup of current state before restore

---

## 📋 Migration Checklist

### Before Running
- [ ] Read MIGRATION-QUICK-START.md
- [ ] Committed and pushed all changes
- [ ] Team is aware migration is happening
- [ ] Using plan-only mode (not apply)
- [ ] Environment set to `cs`

### During Migration
- [ ] Monitoring pipeline execution
- [ ] Watching for errors
- [ ] Noting backup file path

### After Migration (Success)
- [ ] Verified: 0 to add, 0 to change, 0 to destroy
- [ ] Tested Walmart deployment (optional)
- [ ] Removed migration code from pipeline
- [ ] Pushed cleanup commit
- [ ] Updated team on completion

### After Migration (Failure)
- [ ] Noted which resource failed
- [ ] Captured backup file path
- [ ] Decided on restore or retry
- [ ] Consulted RESTORE-FROM-BACKUP.md
- [ ] Contacted team if needed

---

## 🎓 Understanding the Migration

### The Problem
```
OLD STATE PATH:  module.web_resources.module.keyvault[0].azurerm_key_vault.main
NEW CODE EXPECTS: module.web_resources[0].module.keyvault[0].azurerm_key_vault.main
                                     ^^^
                                Notice the [0] here!
```

Terraform thinks these are different resources → wants to destroy/recreate

### The Solution
```bash
terraform state mv \
  'module.web_resources.module.keyvault[0].azurerm_key_vault.main' \
  'module.web_resources[0].module.keyvault[0].azurerm_key_vault.main'
```

Do this for all 163 resources → Terraform now recognizes them → 0 changes!

### Why It's Safe
- Only modifies Terraform state file (internal bookkeeping)
- Does NOT make any Azure API calls
- Does NOT touch actual infrastructure
- Can be rolled back via restore

---

## 🔧 What Gets Migrated

All resources under these modules:
- `module.hub_infrastructure.*` → `module.hub_infrastructure[0].*`
- `module.sftp.*` → `module.sftp[0].*`
- `module.web_resources.*` → `module.web_resources[0].*`
- `module.app_resources.*` → `module.app_resources[0].*`
- `module.db_resources_02.*` → `module.db_resources_02[0].*`
- `module.db_key_vault.*` → `module.db_key_vault[0].*`
- `module.ado_resources.*` → `module.ado_resources[0].*`

**Total**: ~163 resources (exact count may vary)

---

## 📞 Support

### If Migration Succeeds
- ✅ No action needed
- ✅ Proceed with normal operations
- ✅ Remove migration code

### If Migration Fails
1. **Don't panic** - you have backups
2. Check pipeline logs for error details
3. Consult RESTORE-FROM-BACKUP.md
4. Contact DevOps team if unsure
5. DO NOT run apply until resolved

### If Something Seems Wrong
1. Run `terraform plan` to check status
2. Compare with expected results
3. Restore from backup if needed
4. Ask team before proceeding

---

## ⏱️ Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Setup | 5 min | Commit and push changes |
| Migration | 10-15 min | Pipeline runs migration |
| Verification | 2 min | Confirm success |
| Cleanup | 5 min | Remove migration code |
| **Total** | **~25 min** | End-to-end |

Plus optional Walmart testing: +10 min

---

## 🎯 Success Criteria

Migration is successful when:
- ✅ All 163 resources migrated without error
- ✅ Verification shows: 0 to add, 0 to change, 0 to destroy
- ✅ Final plan shows: "No changes. Infrastructure matches configuration."
- ✅ No warnings or errors in logs

---

## 🔮 After Migration

### For CS Environment
Everything works as before, just with updated state paths:
```bash
# Run pipeline normally
Product: em_bofa
Environment: cs
Action: plan-and-apply
```

### For Walmart Environment
Now you can deploy networking:
```bash
# Run pipeline for Walmart
Product: em_bofa
Environment: walmart
Action: plan-and-apply
```

### Future Environments
Just create new tfvars with enable flags:
```hcl
enable_hub = true/false
enable_web_vms = true/false
# etc...
```

---

## 📚 Additional Resources

- Terraform State Commands: https://www.terraform.io/docs/cli/commands/state/
- Azure DevOps Pipelines: https://docs.microsoft.com/azure/devops/pipelines/
- Count Meta-Argument: https://www.terraform.io/docs/language/meta-arguments/count.html

---

## 📝 Notes

- This is a **one-time migration** for CS environment
- Walmart and future environments do NOT need migration (they start fresh)
- Migration code should be **removed after successful completion**
- Keep documentation for future reference
- Backups are retained for safety

---

**Ready?** Start with `MIGRATION-QUICK-START.md` and follow the steps! 🚀
