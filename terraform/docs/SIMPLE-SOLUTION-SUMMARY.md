# Simple Solution: One main.tf with Enable Flags

## ✅ What We Did

**Implemented simple flag-based control** - No separate files, just ONE `main.tf` for ALL environments!

## How It Works

### 1. Control via tfvars Files

Each environment controls what gets deployed via simple boolean flags:

**walmart.tfvars** (Networking only):
```hcl
enable_hub     = false  # Use shared CS hub
enable_sftp    = false
enable_web_vms = false
enable_app_vms = false
enable_db_vms  = false
enable_ado_vms = false
enable_aks     = false
use_shared_hub = true   # Connect to CS hub
```

**cs.tfvars** (Full stack):
```hcl
enable_hub     = true   # Create dedicated hub
enable_sftp    = true
enable_web_vms = true
enable_app_vms = true
enable_db_vms  = true
enable_ado_vms = true
enable_aks     = false  # Not yet implemented
```

### 2. One main.tf Handles Everything

```hcl
# Modules use count based on enable flags
module "hub_infrastructure" {
  count = var.enable_hub ? 1 : 0  # Only if enabled
  ...
}

module "web_resources" {
  count = var.enable_web_vms ? 1 : 0  # Only if enabled
  ...
}

# Spoke always created (every environment needs one)
module "spoke_vnet" {
  source = "./modules/azure"
  ...
}
```

### 3. Smart Peering

Handles both scenarios automatically:

```hcl
# If use_shared_hub=true: Connect to CS hub
# If use_shared_hub=false: Connect to own hub
remote_virtual_network_id = var.use_shared_hub ?
  data.azurerm_virtual_network.shared_hub[0].id :
  module.hub_infrastructure[0].vnet_id
```

## Deploy Walmart (Networking Only)

```bash
terraform plan -var-file="environments/em_bofa/walmart.tfvars"
```

**What Gets Created**:
- ✅ Walmart Spoke VNet (`10.225.0.0/21`)
- ✅ 7 Subnets
- ✅ NAT Gateway
- ✅ VNet Peering to CS Hub
- ❌ NO hub (uses CS hub)
- ❌ NO VMs, AKS, SFTP, etc.

## Deploy CS (Full Stack)

```bash
terraform plan -var-file="environments/em_bofa/cs.tfvars"
```

**What Gets Created**:
- ✅ CS Hub VNet (`10.223.40.0/24`)
- ✅ VPN Gateway
- ✅ CS Spoke VNet (`10.223.48.0/21`)
- ✅ Web VMs
- ✅ App VMs
- ✅ DB VMs
- ✅ ADO agents
- ✅ SFTP
- ✅ Application Gateway

## Enable More Resources for Walmart (Phase 2)

Just change flags in `walmart.tfvars`:

```hcl
# Phase 2: Add compute resources
enable_web_vms = true   # ← Change from false to true
enable_app_vms = true   # ← Change from false to true
enable_db_vms  = true   # ← Change from false to true
```

Run terraform apply again - it will add the VMs!

## Benefits

1. ✅ **One main.tf** - No separate files per environment
2. ✅ **Simple flags** - Easy to understand what's enabled
3. ✅ **Scalable** - Add more environments easily
4. ✅ **Phase deployments** - Start with networking, add compute later
5. ✅ **No duplication** - Same code for all environments

## Files Summary

### Keep:
- ✅ `main.tf` - Main configuration (works for ALL environments)
- ✅ `variables.tf` - Includes enable flags
- ✅ `environments/em_bofa/cs.tfvars` - CS config with flags
- ✅ `environments/em_bofa/walmart.tfvars` - Walmart config with flags
- ✅ `environments/em_bofa/dev.tfvars` - Dev config
- ✅ `environments/em_bofa/prod.tfvars` - Prod config

### Delete:
- ❌ `main-walmart-networking-only.tf` - Not needed! (already deleted)
- ❌ `main-scalable.tf` - Not needed! (already deleted)
- ❌ `shared-hub.tfvars` - Not needed!

## Quick Reference

| Flag | Purpose | Walmart | CS | Dev/Prod |
|------|---------|---------|----|---------
| `enable_hub` | Create hub VNet | `false` | `true` | `true` |
| `enable_sftp` | SFTP storage | `false` | `true` | varies |
| `enable_web_vms` | Web tier VMs | `false` (Phase 1) | `true` | varies |
| `enable_app_vms` | App tier VMs | `false` (Phase 1) | `true` | varies |
| `enable_db_vms` | Database VMs | `false` (Phase 1) | `true` | varies |
| `enable_ado_vms` | DevOps agents | `false` (Phase 1) | `true` | varies |
| `enable_aks` | AKS cluster | `false` | `false` | varies |
| `use_shared_hub` | Use CS hub | `true` | `false` | `false` |

## That's It!

Simple, clean, scalable. ONE main.tf, control via flags. ✨

---

**No more complex files. No more confusion. Just simple flags!** 🎯
