# Walmart Subnet Issue - Fix Summary

## Problem
When running the multi-env pipeline for Walmart environment, Terraform was attempting to create subnets with **CS IP ranges (10.223.x.x)** instead of **Walmart IP ranges (10.225.x.x)**, causing Azure to reject the changes with:

```
Error: Subnet 'US1-WM-P-SPOKE-DB-SUBNET' is not valid because its IP address 
range is outside the IP address range of virtual network 'US1-WM-P-SPOKE-VNET'.
```

## Root Cause

**Critical Bug in `pipelines/templates/plan.yml`**:

The template was checking for compile-time parameter `${{ parameters.tfVarsFile }}` instead of runtime variable `$(tfVarsFile)`:

```bash
# WRONG - This always evaluated to false at runtime
if [ -n "${{ parameters.tfVarsFile }}" ]; then
  VARS_FILE="${{ parameters.tfVarsFile }}"
else
  VARS_FILE="environments/${{ parameters.environment }}.tfvars"  # Used this: environments/walmart.tfvars
fi
```

Since `environments/walmart.tfvars` doesn't exist (the actual path is `environments/em_bofa/walmart.tfvars`), Terraform couldn't find the vars file and fell back to **default values from `variables.tf`**, which contain CS IP ranges.

## The Fix

### 1. Fixed plan.yml Template ✅

Updated the logic to properly check the runtime variable:

```bash
# CORRECT - Checks runtime variable first
if [ -n "$(tfVarsFile)" ]; then
  VARS_FILE="$(tfVarsFile)"  # Uses: environments/em_bofa/walmart.tfvars
  echo "✓ Using tfVarsFile variable from pipeline"
elif [ -n "${{ parameters.tfVarsFile }}" ]; then
  VARS_FILE="${{ parameters.tfVarsFile }}"
  echo "✓ Using tfVarsFile parameter"
else
  VARS_FILE="environments/${{ parameters.environment }}.tfvars"
  echo "✓ Using default path from environment parameter"
fi
```

### 2. Enhanced Debugging ✅

Added comprehensive logging to both `plan.yml` and `apply.yml`:

**Plan stage now shows**:
- Exact tfvars file path being used
- File existence verification
- First 30 lines of the tfvars file content
- Network configuration from the file
- Removal of stale plan files before creating new ones

**Apply stage now shows**:
- Plan file verification
- Plan file summary with resources and IP ranges
- Confirmation before applying

### 3. Documentation ✅

Created helpful documentation:
- `QUICK-FIX-WALMART.md` - Quick reference for the issue and fix
- `docs/WALMART-SUBNET-FIX.md` - Detailed analysis and troubleshooting
- `WALMART-FIX-SUMMARY.md` - This file

## Files Modified

```
M  pipelines/templates/plan.yml      # Fixed tfVarsFile variable check + enhanced logging
M  pipelines/templates/apply.yml     # Enhanced logging and plan verification
A  QUICK-FIX-WALMART.md              # Quick reference guide
A  docs/WALMART-SUBNET-FIX.md        # Detailed troubleshooting guide
A  WALMART-FIX-SUMMARY.md            # This summary
A  scripts/verify-walmart-config.sh  # Local verification script (optional)
```

## What to Do Now

### Step 1: Commit and Push (if not already done)
```bash
git add .
git commit -m "Fix: Walmart environment using wrong subnet IP ranges

- Fixed plan.yml to properly use runtime tfVarsFile variable
- Enhanced logging in plan and apply templates
- Added documentation for troubleshooting"
git push origin isw-301-walmart
```

### Step 2: Run the Pipeline

Run the multi-env pipeline with:
- **Product**: `em_bofa`
- **Environment**: `walmart`
- **Use Current Branch**: ✓ (checked)
- **Action**: `plan-and-apply`

### Step 3: Verify the Output

Look for these lines in the Plan stage logs:
```
✓ Using tfVarsFile variable from pipeline
Using vars file: environments/em_bofa/walmart.tfvars
✓ Vars file found: environments/em_bofa/walmart.tfvars

Network configuration in tfvars:
spoke_vnet_address_space = "10.225.0.0/21"
address_prefix    = "10.225.0.0/24"
address_prefix    = "10.225.1.0/24"
address_prefix    = "10.225.2.0/24"
...
```

### Step 4: Verify Resources Created

After successful deployment, verify in Azure Portal:

```
Resource Group: US1-WM-P-SPOKE
VNet: US1-WM-P-SPOKE-VNET (10.225.0.0/21)
Subnets:
  ✓ US1-WM-P-SPOKE-WEB-SUBNET:  10.225.0.0/24
  ✓ US1-WM-P-SPOKE-APP-SUBNET:  10.225.1.0/24
  ✓ US1-WM-P-SPOKE-DB-SUBNET:   10.225.2.0/24
  ✓ US1-WM-P-SPOKE-ADO-SUBNET:  10.225.3.0/24
  ✓ US1-WM-P-SPOKE-LOGI-SUBNET: 10.225.4.0/24
  ✓ US1-WM-P-SPOKE-AG-SUBNET:   10.225.5.0/24
  ✓ US1-WM-P-SPOKE-SFTP-SUBNET: 10.225.6.0/24
```

## If You Still Get Errors

If subnets were already created with wrong IP ranges (unlikely since you said there are no subnets yet), see `QUICK-FIX-WALMART.md` for steps to remove them from state and Azure.

## Why This Wasn't Caught Earlier

1. **CS environment works fine** because it doesn't specify a product in the path (`environments/cs.tfvars` exists)
2. **The variable worked in other templates** (refresh.yml, import-resources.yml) because they used `$(tfVarsFile)` correctly
3. **No error was shown** about missing tfvars file - Terraform silently used default values

## Prevention

This fix includes:
- ✅ Proper runtime variable checking in plan.yml
- ✅ Detailed logging showing which file is being used
- ✅ File existence verification before planning
- ✅ Network configuration display from tfvars
- ✅ Stale plan file cleanup

These enhancements will make it immediately obvious if the wrong vars file is being used in future deployments.

---

**Status**: ✅ Issue identified and fixed. Ready to deploy.
