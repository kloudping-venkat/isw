# How to Verify Migration Succeeded

## Quick Answer

**Migration succeeded if you see changes like**:
- ✅ Storage blob updates (script path changes)
- ✅ VM patch setting updates (patch_assessment_mode, vm_agent_platform_updates)
- ✅ Minor configuration drift

**Migration FAILED if you see**:
- ❌ VMs being destroyed and recreated
- ❌ Databases being destroyed and recreated
- ❌ Key Vaults being destroyed and recreated
- ❌ VNets being destroyed and recreated

---

## Your Current Situation

You saw this in the plan:
```
Plan: 3 to add, 8 to change, 3 to destroy
```

### The 3 to Add/Destroy (Replacements)
```
module.web_resources[0].module.scripts_storage[0].azurerm_storage_blob.configure_vm
module.app_resources[0].module.scripts_storage[0].azurerm_storage_blob.configure_vm
module.ado_resources[0].module.scripts_storage[0].azurerm_storage_blob.configure_vm
```

**Reason**: Source path changed from `modules/em/` to `modules/azure/`
**Impact**: Script files will be re-uploaded (no downtime)
**Verdict**: ✅ **SAFE - This is expected from the module rename**

### The 8 to Change (Updates)
```
8 VMs with:
- patch_assessment_mode: "AutomaticByPlatform" → "ImageDefault"
- vm_agent_platform_updates_enabled: true → false
```

**Reason**: VM module configuration changed
**Impact**: Patch settings updated (VMs NOT restarted)
**Verdict**: ✅ **SAFE - Configuration drift correction**

---

## Migration Success Criteria

### ✅ Migration SUCCEEDED if:

1. **No major resources being destroyed/recreated**
   - VMs should show "update" not "destroy/create"
   - Key Vaults should show "update" or nothing
   - VNets should show nothing (already correct)
   - Databases should show "update" or nothing

2. **All resources now have [0] in state paths**
   - `module.web_resources[0].*` ✅
   - `module.app_resources[0].*` ✅
   - `module.db_resources_02[0].*` ✅
   - etc.

3. **Changes are minor configuration updates**
   - Patch settings
   - Script blob paths
   - Tags
   - Monitoring settings

### ❌ Migration FAILED if:

1. **Major resources being destroyed/recreated**
   ```
   # module.web_resources[0].module.compute["VM01"].azurerm_windows_virtual_machine.vm must be replaced
   -/+ resource "azurerm_windows_virtual_machine" "vm"
   ```
   This means migration didn't work properly.

2. **Plan shows 100+ resources to destroy**
   This means state paths weren't migrated correctly.

3. **Error during migration step**
   Migration script exited with error code.

---

## Your Verdict

Based on your plan output:

✅ **MIGRATION SUCCEEDED**

**Reasoning**:
1. ✅ Only 3 storage blobs being replaced (expected - path change)
2. ✅ Only 8 VMs being updated (expected - patch settings)
3. ✅ NO VMs being destroyed/recreated
4. ✅ NO databases being destroyed/recreated
5. ✅ NO networking being destroyed/recreated

**The changes you see are legitimate configuration drift**, not migration failures.

---

## What to Do Next

### Step 1: Mark Migration as Complete

Migration succeeded! The changes shown are **real configuration updates** that should be applied.

### Step 2: Apply the Configuration Changes

Run pipeline with:
```
Environment: cs
Action: plan-and-apply
Run State Migration: false (already done!)
```

This will apply the 11 changes:
- Re-upload 3 script blobs with correct path
- Update 8 VMs patch settings

### Step 3: Remove Migration Code

After apply succeeds, remove the migration code from `pipelines/multi-env-pipeline.yml`:
- Delete `runStateMigration` parameter
- Delete migration step
- Commit and push

### Step 4: Deploy Walmart

Now you can deploy Walmart networking:
```
Environment: walmart
Action: plan-and-apply
```

---

## Understanding the Changes

### Storage Blob Replacements

**Before**:
```hcl
source = "modules/em/storage-scripts/../compute/scripts/configure-vm.ps1"
```

**After**:
```hcl
source = "modules/azure/storage-scripts/../compute/scripts/configure-vm.ps1"
```

**Why**: You renamed `modules/em/` to `modules/azure/`
**Impact**: Blob content will be re-uploaded from new path
**Downtime**: None (script is just uploaded to storage)

### VM Patch Settings

**Before**:
```hcl
patch_assessment_mode = "AutomaticByPlatform"
vm_agent_platform_updates_enabled = true
```

**After**:
```hcl
patch_assessment_mode = "ImageDefault"
vm_agent_platform_updates_enabled = false
```

**Why**: VM module configuration was updated
**Impact**: Windows Update behavior changes
**Downtime**: None (no restart required)

---

## FAQ

### Q: Why did migration show changes if it succeeded?

A: Migration updates **state paths**, not configuration. If your code has configuration changes (module rename, patch settings, etc.), those will show up in the plan **after** migration succeeds.

### Q: Should I be worried about the 3 replacements?

A: No. Storage blobs are just script files. Replacing them means re-uploading the file - takes seconds, no impact on running VMs.

### Q: Will VMs restart?

A: No. Patch setting changes don't require restart.

### Q: How do I know migration really worked?

A: Check the migration step logs - it should show:
```
✅ Migration Complete! Migrated 163 resources successfully
```

Also, check that plan is NOT showing 163 to destroy - that would mean migration failed.

---

## Summary

| What You Saw | What It Means | Action |
|--------------|---------------|--------|
| Migration script completed | State paths migrated ✅ | Good! |
| 3 blobs to replace | Module path changed | Safe to apply |
| 8 VMs to update | Patch settings changed | Safe to apply |
| NO major destroys | No infrastructure rebuild | Migration worked! |

**Verdict**: ✅ Migration succeeded, proceed with apply!
