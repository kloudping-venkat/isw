# Import Existing SFTP Storage Account

## Issue
Storage account `us1bofacssftp` already exists in Azure but is not in Terraform state, causing a 409 Conflict error.

## Solution: Import the Existing Storage Account

Run this command in your Azure DevOps pipeline or locally:

```bash
terraform import \
  'module.sftp.azurerm_storage_account.main[0]' \
  /subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SFTP/providers/Microsoft.Storage/storageAccounts/us1bofacssftp
```

## What This Does

This tells Terraform:
- "The storage account `us1bofacssftp` already exists"
- "Add it to my state file"
- "Next time I run `terraform apply`, update it instead of creating it"

## After Import

Run `terraform plan` again and you should see:
- ✅ Storage account will be **updated in-place** (not recreated)
- ✅ Will add versioning=false, soft delete, change feed, etc.
- ✅ No 409 Conflict error

## Alternative: Different Storage Account Name

If you want a fresh start with a different name, change in `main.tf`:

```hcl
storage_account_name = "us1bofacssftp2"  # or "us1bofacssftpnew"
```

**Recommendation**: Import the existing one to preserve any data already uploaded.
