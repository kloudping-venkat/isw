# Decommissioning DB VM01 - Step-by-Step Guide

## Overview
This guide walks through safely decommissioning DB-VM01 while keeping DB-VM02 operational with proper NSG ownership.

## What Changed in Terraform
- ✅ Removed `module.db_resources` (DB-VM01)
- ✅ Removed `random_password.oracle_admin_password` (DB-VM01 password)
- ✅ Updated DB-VM02 to own and create the NSG (`create_nsg = true`)
- ✅ Removed DB-VM02's dependency on DB-VM01's NSG

---

## Option 1: Two-Step Approach (RECOMMENDED - Safest)

### Step 1: Remove DB-VM01 from State (No Azure Changes)
This removes DB-VM01 from Terraform tracking WITHOUT deleting it from Azure.

**Pipeline Settings:**
```
Terraform Action: plan-only
☑️ Remove Resources from State
State Remove List: module.db_resources,random_password.oracle_admin_password
```

**What happens:**
- Terraform forgets about DB-VM01 (removes from state)
- DB-VM01 still exists in Azure (no deletion)
- NSG remains in Azure, managed by DB-VM01

### Step 2: Transfer NSG Ownership and Delete VM01

**Before running this step:**
- Verify Step 1 completed successfully
- Check that DB-VM02 state shows `create_nsg = true`

**Pipeline Settings:**
```
Terraform Action: plan-and-apply
```

**What happens:**
- DB-VM02 takes ownership of existing NSG (no recreation)
- Plan will show DB-VM01 is NOT managed by Terraform
- No actual Azure changes (NSG already exists)

**After Apply:**
- Manually delete DB-VM01 from Azure Portal OR
- Use Azure CLI:
  ```bash
  az vm delete --name US1-BOFA-CS-DB-VM01 --resource-group US1-BOFA-CS-DB --yes
  az disk delete --name US1-BOFA-CS-DB-VM01-osdisk --resource-group US1-BOFA-CS-DB --yes
  az disk delete --name US1-BOFA-CS-DB-VM01-datadisk-* --resource-group US1-BOFA-CS-DB --yes
  az network interface delete --name US1-BOFA-CS-DB-VM01-nic --resource-group US1-BOFA-CS-DB
  ```

---

## Option 2: Direct Approach (Requires NSG Import)

### Step 1: Import NSG to DB-VM02
The NSG already exists and was created by DB-VM01. We need to import it to DB-VM02's state.

**Get NSG Resource ID:**
```bash
az network nsg show \
  --name US1-BOFA-CS-DB-NSG \
  --resource-group US1-BOFA-CS-DB \
  --query id -o tsv
```

**Pipeline Settings:**
```
Terraform Action: plan-only
☑️ Custom Import List
Custom Import List: module.db_resources_02.azurerm_network_security_group.oracle_nsg[0]|/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Network/networkSecurityGroups/US1-BOFA-CS-DB-NSG
```

### Step 2: Apply Changes
**Pipeline Settings:**
```
Terraform Action: plan-and-apply
```

**What happens:**
- DB-VM01 and all its resources will be destroyed
- DB-VM02 takes ownership of imported NSG
- NSG remains intact (no changes)

---

## Option 3: Clean Slate Approach (Advanced - Requires Downtime)

### Step 1: Remove Both VMs from State
```
State Remove List: module.db_resources,module.db_resources_02,random_password.oracle_admin_password,random_password.oracle_admin_password_02
```

### Step 2: Manually Delete DB-VM01 and NSG
Delete DB-VM01 and NSG from Azure Portal

### Step 3: Run Terraform Apply
This will create DB-VM02 fresh with a new NSG

⚠️ **Warning:** This causes downtime for DB-VM02

---

## Resources to Remove from State

Complete list of DB-VM01 resources:
```
module.db_resources
module.db_resources.azurerm_linux_virtual_machine.vm
module.db_resources.azurerm_network_interface.oracle_nic
module.db_resources.azurerm_network_interface_security_group_association.oracle_nic_nsg
module.db_resources.azurerm_network_security_group.oracle_nsg[0]
module.db_resources.azurerm_network_security_rule.oracle_listener[0]
module.db_resources.azurerm_network_security_rule.oracle_sqlnet[0]
module.db_resources.azurerm_network_security_rule.oracle_enterprise_manager[0]
module.db_resources.azurerm_network_security_rule.smb[0]
module.db_resources.azurerm_managed_disk.oracle_data_disks[0]
module.db_resources.azurerm_managed_disk.oracle_data_disks[1]
module.db_resources.azurerm_managed_disk.oracle_data_disks[2]
module.db_resources.azurerm_virtual_machine_data_disk_attachment.oracle_data_disk_attachment[0]
module.db_resources.azurerm_virtual_machine_data_disk_attachment.oracle_data_disk_attachment[1]
module.db_resources.azurerm_virtual_machine_data_disk_attachment.oracle_data_disk_attachment[2]
module.db_resources.azurerm_key_vault_secret.db_admin_password[0]
module.db_resources.azurerm_key_vault_secret.db_connection_string[0]
random_password.oracle_admin_password
```

**Shortcut:** You can just remove the entire module:
```
module.db_resources,random_password.oracle_admin_password
```

---

## Verification Commands

### Check State Contents
```bash
terraform state list | grep db_resources
```

### Check NSG in Azure
```bash
az network nsg show --name US1-BOFA-CS-DB-NSG --resource-group US1-BOFA-CS-DB
```

### Check NSG Rules
```bash
az network nsg rule list --nsg-name US1-BOFA-CS-DB-NSG --resource-group US1-BOFA-CS-DB -o table
```

---

## Rollback Plan

If something goes wrong:

1. **Revert Terraform code:**
   ```bash
   git checkout HEAD~1 terraform/main.tf
   ```

2. **Re-import DB-VM01:**
   ```bash
   terraform import module.db_resources.azurerm_linux_virtual_machine.vm /subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-DB/providers/Microsoft.Compute/virtualMachines/US1-BOFA-CS-DB-VM01
   ```

---

## Recommended Approach

**Use Option 1 (Two-Step Approach)**
- Safest method
- No risk of accidental deletion
- Easy to verify at each step
- Can rollback easily
- DB-VM02 stays operational throughout

---

## Questions?

- **Will DB-VM02 lose its NSG?** No, the NSG will remain in Azure
- **Will there be downtime?** No, DB-VM02 continues running
- **What if the import fails?** Use Option 1 instead
- **Can I rollback?** Yes, see Rollback Plan above

---

## Files Modified

1. `terraform/main.tf` - Removed DB-VM01 module and password
2. `pipelines/cs-azure-pipeline.yml` - Added state removal parameters
3. `pipelines/templates/state-remove.yml` - NEW template for state removal
