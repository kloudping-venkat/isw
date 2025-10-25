# Walmart - Quick Check

## Step 1: Check VNet in Azure Portal

Go to Azure Portal and check:
- Resource Group: `US1-WM-P-SPOKE`
- VNet: `US1-WM-P-SPOKE-VNET`
- Look at **Address space**

### What it should be:
```
Address space: 10.225.0.0/21
```

### If it's wrong (10.223.x.x):
**The VNet was created with CS address space!** This is the problem.

**Fix**: You need to either:
1. Delete the VNet and recreate it with correct address space
2. Or modify the VNet address space (but this requires deleting all subnets first)

## Step 2: Share Plan Logs

From your pipeline run, find the "Terraform Plan" step and share:

1. **The configuration section**:
```
=== Terraform Plan Configuration ===
tfVarsFile variable: '???'
...
Using vars file: ???
```

2. **The network config section**:
```
Network configuration in tfvars:
spoke_vnet_address_space = ???
address_prefix = ???
```

3. **The plan output for VNet**:
```
# module.spoke_vnet.module.networking[0].module.vnet.azurerm_virtual_network.vnet will be created/updated
  + resource "azurerm_virtual_network" "vnet" {
      + address_space = [
          + "???.???.???.???/21"
        ]
```

4. **The plan output for one subnet**:
```
# module.spoke_vnet.module.networking[0].module.vnet.azurerm_subnet.subnet_for_each["US1-WM-P-SPOKE-DB-SUBNET"] will be created
  + resource "azurerm_subnet" "subnet_for_each" {
      + address_prefixes = [
          + "???.???.???.???/24"
        ]
```

## Most Likely Issue

Based on the error, I suspect:
- ✅ VNet `US1-WM-P-SPOKE-VNET` exists
- ❌ VNet has **WRONG address space** (10.223.x.x instead of 10.225.x.x)
- ❌ Terraform is trying to create subnets with ranges that don't fit in the VNet

## Quick Fix if VNet has wrong address space:

### Option 1: Delete and Recreate (RECOMMENDED)
```bash
# In Azure Portal:
1. Delete VNet: US1-WM-P-SPOKE-VNET
2. Re-run terraform apply
```

### Option 2: Fix via Terraform
```bash
# Remove VNet from state
terraform state rm 'module.spoke_vnet.module.networking[0].module.vnet.azurerm_virtual_network.vnet'

# Delete VNet in Azure Portal

# Re-run terraform apply to recreate with correct address space
```

## What to check RIGHT NOW:

**Go to Azure Portal → US1-WM-P-SPOKE resource group → US1-WM-P-SPOKE-VNET → Overview**

What is the **Address space** shown?
- If it shows `10.223.40.0/24` or `10.223.48.0/21` → **WRONG - This is CS address space**
- If it shows `10.225.0.0/21` → **CORRECT - Problem is elsewhere**

Tell me what you see!
