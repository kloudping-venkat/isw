# Flag-Based Approach Guide

## Overview

We use **enable flags** in tfvars to control which modules get deployed. This is clean, simple, and scalable.

## How It Works

### CS Environment (Full Stack)
```hcl
# cs.tfvars
enable_hub     = true
enable_sftp    = true
enable_web_vms = true
enable_app_vms = true
enable_db_vms  = true
enable_ado_vms = true
```

**Result**: All modules deployed ✅

### Walmart Environment (Networking Only)
```hcl
# walmart.tfvars
enable_hub     = false  # Use shared CS hub
enable_sftp    = false
enable_web_vms = false
enable_app_vms = false
enable_db_vms  = false
enable_ado_vms = false
use_shared_hub = true   # Connect to CS hub
```

**Result**: Only spoke network + peering ✅

## One-Time Migration for CS

Since modules now use `count`, existing CS resources need state migration. This will move ALL resources from `module.X.*` to `module.X[0].*`:

```bash
cd terraform

# 1. Initialize terraform (required for state operations)
terraform init

# 2. Backup state
terraform state pull > state-backup-$(date +%Y%m%d).json

# 3. Run migration script (this will migrate ALL 163+ resources automatically)
./migrate-cs-state-fixed.sh

# 4. Verify
terraform plan -var-file="environments/em_bofa/cs.tfvars"
# Should show: 0 to add, 0 to change, 0 to destroy ✅
```

**What the migration does:**
- Moves all resources from `module.web_resources.*` → `module.web_resources[0].*`
- Moves all resources from `module.app_resources.*` → `module.app_resources[0].*`
- Moves all resources from `module.db_resources_02.*` → `module.db_resources_02[0].*`
- Moves all resources from `module.db_key_vault.*` → `module.db_key_vault[0].*`
- Moves all resources from `module.hub_infrastructure.*` → `module.hub_infrastructure[0].*`
- Moves all resources from `module.sftp.*` → `module.sftp[0].*`
- Moves all resources from `module.ado_resources.*` → `module.ado_resources[0].*`

This is safe and does NOT destroy any resources - it only updates the state file paths.

## Deploy Walmart (No Migration Needed)

```bash
# Walmart is new, no migration needed
terraform init
terraform plan -var-file="environments/em_bofa/walmart.tfvars"
terraform apply -var-file="environments/em_bofa/walmart.tfvars"
```

## Benefits

1. ✅ **One main.tf** - Works for all environments
2. ✅ **Simple flags** - Easy to control what gets deployed
3. ✅ **Phase deployments** - Start with networking, add VMs later
4. ✅ **No duplication** - Same code for everyone
5. ✅ **Scalable** - Add more environments easily

## Phase 2: Add Compute to Walmart

Just edit `walmart.tfvars`:

```hcl
enable_web_vms = true  # ← Change to true
enable_app_vms = true  # ← Change to true
```

Run `terraform apply` - it will add the VMs!

---

**Simple, clean, scalable!** 🎯
