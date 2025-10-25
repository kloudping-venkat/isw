# Quick Fix: Walmart Subnet IP Range Issue

## The Problem
Terraform is trying to use CS IP ranges (10.223.x.x) instead of Walmart IP ranges (10.225.x.x) when creating subnets.

**Root Cause**: The `plan.yml` template had a bug where it was checking for compile-time parameter `${{ parameters.tfVarsFile }}` instead of runtime variable `$(tfVarsFile)`. This caused it to always fall back to the default path `environments/walmart.tfvars` (which doesn't exist), so it used default variable values from `variables.tf` (CS ranges).

**Status**: ✅ **FIXED** in this commit

## The Fix

### ✅ Bug Fixed - Just Run the Pipeline

The issue has been fixed in the code. Simply run the pipeline:

1. **Commit and push this branch** (if not already done)
2. **Run the multi-env pipeline** with:
   - Product: `em_bofa`
   - Environment: `walmart`
   - **Use Current Branch**: ✓ (important!)
   - Action: `plan-and-apply`

The enhanced logging will now show you're using the correct file:
```
✓ Using tfVarsFile variable from pipeline
Using vars file: environments/em_bofa/walmart.tfvars
spoke_vnet_address_space = "10.225.0.0/21"
```

---

### 🔍 If It Still Fails - Old Subnets Exist

If you still get the error after the fix, it means subnets already exist in Azure with wrong IP ranges:

#### Quick Steps:
1. **Remove from state** - Run pipeline with these settings:
   - Product: `em_bofa`
   - Environment: `walmart`  
   - **Remove Resources from State**: ✓ 
   - State Remove List: `module.spoke_vnet.module.networking[0].module.vnet.azurerm_subnet.subnet_for_each["US1-WM-P-SPOKE-DB-SUBNET"],module.spoke_vnet.module.networking[0].module.vnet.azurerm_subnet.subnet_for_each["US1-WM-P-SPOKE-APP-SUBNET"],module.spoke_vnet.module.networking[0].module.vnet.azurerm_subnet.subnet_for_each["US1-WM-P-SPOKE-LOGI-SUBNET"],module.spoke_vnet.module.networking[0].module.vnet.azurerm_subnet.subnet_for_each["US1-WM-P-SPOKE-WEB-SUBNET"]`

2. **Delete from Azure Portal**:
   - Go to: Resource Group `US1-WM-P-SPOKE` → VNet `US1-WM-P-SPOKE-VNET`
   - Delete all subnets with wrong IP ranges (10.223.x.x)

3. **Re-deploy** - Run pipeline with:
   - Product: `em_bofa`
   - Environment: `walmart`
   - **Use Current Branch**: ✓
   - Action: `plan-and-apply`

---

### 🔍 DIAGNOSTIC: Check What's Being Used

Run pipeline with:
- Product: `em_bofa`
- Environment: `walmart`
- **Use Current Branch**: ✓ (important!)
- Action: `plan-only`

**Look for in logs**:
- ✓ `Using vars file: environments/em_bofa/walmart.tfvars`
- ✓ `spoke_vnet_address_space = "10.225.0.0/21"`
- ✓ `address_prefix = "10.225.x.x/24"`

If logs show 10.225.x.x but plan shows 10.223.x.x → **State file has old values, use RECOMMENDED fix**

---

## What Should Exist After Fix

```
VNet: US1-WM-P-SPOKE-VNET (10.225.0.0/21)
├── US1-WM-P-SPOKE-WEB-SUBNET:  10.225.0.0/24 ✓
├── US1-WM-P-SPOKE-APP-SUBNET:  10.225.1.0/24 ✓
├── US1-WM-P-SPOKE-DB-SUBNET:   10.225.2.0/24 ✓
├── US1-WM-P-SPOKE-ADO-SUBNET:  10.225.3.0/24 ✓
├── US1-WM-P-SPOKE-LOGI-SUBNET: 10.225.4.0/24 ✓
├── US1-WM-P-SPOKE-AG-SUBNET:   10.225.5.0/24 ✓
└── US1-WM-P-SPOKE-SFTP-SUBNET: 10.225.6.0/24 ✓
```

## Why This Happened

**The subnets were created with wrong IP ranges** (probably from an old deployment), and now they exist in:
1. Azure (actual infrastructure)
2. Terraform state file (`em_bofa-walmart.tfstate`)

You can't change subnet IP ranges in Azure - you must delete and recreate them.

## Enhanced Logging

The pipeline now includes detailed logging (committed in this PR) that shows:
- Exact tfvars file being used
- Content of the tfvars file
- IP ranges from the file
- Plan file verification before apply

This helps diagnose the issue faster next time.

---

**Need more details?** See `docs/WALMART-SUBNET-FIX.md`
