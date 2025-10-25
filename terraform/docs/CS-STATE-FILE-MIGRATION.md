# CS State File Migration to Consistent Naming

## Overview

We've standardized all environment state files to follow a consistent naming pattern:
- **Pattern**: `{product}-{environment}.tfstate`
- **Container**: `tfstate` (same for all environments)

## State File Naming

| Environment | Old State File | New State File |
|-------------|---------------|----------------|
| CS | `cs.terraform.tfstate` (in `terraform-state-rg-terraform-cs` container) | `em_bofa-cs.tfstate` (in `tfstate` container) |
| Walmart | `em_bofa-walmart.tfstate` | `em_bofa-walmart.tfstate` ✓ (already correct) |
| Dev | N/A (new) | `em_bofa-dev.tfstate` |
| Prod | N/A (new) | `em_bofa-prod.tfstate` |

## Migration Steps (Completed)

### 1. ✅ Uploaded CS State File

The migrated CS state file has been uploaded to the new location:
- **Storage Account**: `stcertentterraform47486`
- **Resource Group**: `rg-terraform-state`
- **Container**: `tfstate`
- **File**: `em_bofa-cs.tfstate`

### 2. ✅ Updated Pipeline Logic

Removed special case logic for CS environment. All environments now use:

```bash
CONTAINER_NAME="tfstate"
STATE_FILE="${PRODUCT}-${ENVIRONMENT}.tfstate"
```

### 3. ✅ Backend Configuration

The pipeline now automatically configures backend.tf as:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stcertentterraform47486"
    container_name       = "tfstate"
    key                  = "em_bofa-cs.tfstate"  # or em_bofa-walmart.tfstate, etc.
    use_msi              = true
  }
}
```

## Benefits of Consistent Naming

1. **Simpler Logic**: No special cases or conditional logic needed
2. **Predictable**: Easy to know which state file each environment uses
3. **Scalable**: Adding new environments follows the same pattern
4. **Maintainable**: Less code, fewer bugs

## Verification

When running the CS pipeline, you should see:

```
=== Backend Configuration ===
Product: em_bofa
Environment: cs
Storage account: stcertentterraform47486
Resource group: rg-terraform-state
Container: tfstate
State file: em_bofa-cs.tfstate
=============================
```

And the plan should show existing resources (not "232 to add").

## Old Container (No Longer Used)

The old CS-specific container can be kept for backup:
- **Container**: `terraform-state-rg-terraform-cs`
- **File**: `cs.terraform.tfstate`

This can be deleted after confirming the new state file works correctly.

## Rollback (If Needed)

If you need to rollback to the old state file location:

1. Revert the init.yml template to use conditional logic
2. Update the container name back to `terraform-state-rg-terraform-cs`
3. Update the state file name back to `cs.terraform.tfstate`

However, this should not be necessary as the migration preserves all resources.

---

**Migration completed**: All environments now use consistent `{product}-{environment}.tfstate` naming in the `tfstate` container.
