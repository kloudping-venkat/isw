# Walmart Deployment - Action Plan

## Current Situation

✅ **The code is already correct** - The fix for using the correct tfvars file was added on Oct 14
✅ **No subnets exist yet** - You confirmed there are no subnets in Walmart environment
❌ **Still getting error** - Terraform is trying to use CS IP ranges (10.223.x.x) instead of Walmart ranges (10.225.x.x)

## Why This Is Happening

Since the code looks correct but you're still getting the wrong IP ranges, the issue is likely:

### Possibility 1: Pipeline Cache / Old Code
The pipeline agent might be using **cached/old code** that doesn't have the correct tfVarsFile logic.

**Solution**: Ensure "Use Current Branch" is checked and the git reset --hard runs

### Possibility 2: Init Step Issues  
The `terraform init` might be pulling wrong module versions or cached data.

**Solution**: Add `-reconfigure` flag or clear `.terraform` directory

### Possibility 3: Plan File from Previous Run
An old plan file `plan_walmart.tfplan` might exist from a previous failed run.

**Solution**: Delete the plan file before running (already added cleanup in current code)

## Action Plan

### Step 1: Run Diagnostic Pipeline

Run the multi-env pipeline with:
- Product: `em_bofa`
- Environment: `walmart`
- **Use Current Branch**: ✓ (**IMPORTANT** - checked)
- Action: `plan-only`

### Step 2: Check the Logs

Look for these specific sections in the pipeline output:

#### A. Git Checkout Section
```
✅ Using current branch: isw-301-walmart
Fetching latest changes from origin...
Resetting to latest remote state...
✅ Updated to latest version of isw-301-walmart

Current commit:
031a829 fixed subnet cidr for walmart
```

#### B. Terraform Plan Configuration Section
```
=== Terraform Plan Configuration ===
tfVarsFile variable: 'environments/em_bofa/walmart.tfvars'
parameters.tfVarsFile: 'environments/em_bofa/walmart.tfvars'
parameters.environment: 'walmart'
====================================

✓ Using tfVarsFile variable from pipeline
Using vars file: environments/em_bofa/walmart.tfvars
Output plan file: plan_walmart.tfplan

✓ Vars file found: environments/em_bofa/walmart.tfvars

File content (first 30 lines):
# Walmart Environment Configuration...
location_code = "US1"
client        = "WM"
environment   = "P"
...
spoke_vnet_address_space = "10.225.0.0/21"

Network configuration in tfvars:
spoke_vnet_address_space = "10.225.0.0/21"
    address_prefix    = "10.225.0.0/24"
    address_prefix    = "10.225.1.0/24"
    address_prefix    = "10.225.2.0/24"
```

#### C. Terraform Plan Output
Look for lines like:
```
# module.spoke_vnet.module.networking[0].module.vnet.azurerm_subnet.subnet_for_each["US1-WM-P-SPOKE-DB-SUBNET"] will be created
  + resource "azurerm_subnet" "subnet_for_each" {
      + address_prefixes = [
          + "10.225.2.0/24"   <-- Should be 10.225.x.x, NOT 10.223.x.x
        ]
```

### Step 3: Analyze What You Find

**Scenario A**: Logs show `environments/em_bofa/walmart.tfvars` with 10.225.x.x, but plan shows 10.223.x.x
→ **Problem**: Module or variable substitution issue
→ **Solution**: Check if modules are using correct variables

**Scenario B**: Logs show wrong file path or missing file
→ **Problem**: Git checkout didn't work or wrong code version
→ **Solution**: Verify branch, re-run with clean agent

**Scenario C**: Logs show correct file and correct values (10.225.x.x), plan also shows 10.225.x.x
→ **Success!** The issue is fixed, proceed with apply

**Scenario D**: Logs show correct values but Azure rejects during apply
→ **Problem**: VNet already exists with wrong address space
→ **Solution**: Check VNet `US1-WM-P-SPOKE-VNET` address space in Azure Portal

## Quick Commands for You

### If you need to clear Terraform cache:
Add a step before init to clear `.terraform`:
```bash
rm -rf .terraform
rm -f .terraform.lock.hcl
```

### If VNet exists with wrong address space:
You'll need to delete and recreate the VNet (not just subnets):
1. Remove VNet from state
2. Delete VNet from Azure Portal  
3. Re-run terraform apply

## What I've Added

I've added enhanced logging to the pipeline templates (already in your branch):
- ✅ Detailed file path verification
- ✅ Content display of tfvars file
- ✅ Network configuration display
- ✅ Plan file cleanup before creating new one
- ✅ Plan file verification after creation

## Next Steps

1. **Run the diagnostic** (Step 1 above)
2. **Share the logs** from sections A, B, and C
3. Based on the logs, we'll identify the exact issue
4. Apply the appropriate solution

The code is correct, so we just need to see what's happening at runtime!
