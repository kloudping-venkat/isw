# SFTP Deployment Guide

## ✅ What Was Done

SFTP has been integrated into your existing `main.tf` following your modular pattern.

### Changes Made:

1. **SFTP Subnet Added** - Line 121-124 in `main.tf`
   - Address: `10.223.54.0/24`
   - Service endpoints: Storage, KeyVault

2. **SFTP Module Created** - `/modules/em/sftp/`
   - Reusable SFTP module with NAT Gateway
   - Follows your existing module pattern

3. **SFTP Module Called** - Line 143-185 in `main.tf`
   - Integrated after spoke_vnet module
   - Uses dynamic naming from your variables

4. **Variable Added** - Line 50-55 in `variables.tf`
   - `enable_sftp = true` (default)

5. **Outputs Added** - End of `output.tf`
   - Storage account name
   - NAT Gateway public IP
   - SFTP connection string

### Files Structure:
```
terraform/
├── main.tf                    # SFTP subnet + module call added
├── variables.tf               # enable_sftp variable added
├── output.tf                  # SFTP outputs added
└── modules/em/sftp/          # NEW: SFTP module
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## 🚀 Deploy SFTP

### Option 1: Deploy Everything (Recommended if first time)
```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC/terraform

terraform init
terraform plan
terraform apply
```

### Option 2: Deploy Only SFTP (If infrastructure already exists)
```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC/terraform

terraform init

# Plan only SFTP resources
terraform plan -target=module.sftp

# Apply only SFTP
terraform apply -target=module.sftp
```

---

## 🔧 Control SFTP

### Enable SFTP (default):
Already enabled in `variables.tf`:
```hcl
enable_sftp = true
```

### Disable SFTP:
In your `environments/cs.tfvars` or command line:
```bash
terraform apply -var="enable_sftp=false"
```

---

## 📊 What Gets Created

When `enable_sftp = true`:
- ✅ SFTP Subnet (10.223.54.0/24) in Spoke VNet
- ✅ Storage Account: `us1bofacssftp` (SFTP-enabled, GRS)
- ✅ NAT Gateway: `US1-BOFA-CS-SFTP-NATGW01`
- ✅ NAT Gateway Public IP: `US1-BOFA-CS-SFTP-NATGWPIP01`
- ✅ Private Endpoint for secure access
- ✅ Containers: `uploads`, `downloads`

---

## 🔍 Verify Deployment

After deployment:

```bash
# Get SFTP outputs
terraform output sftp_storage_account_name
terraform output sftp_nat_gateway_public_ip
terraform output sftp_connection_string

# Verify in Azure
az storage account show --name $(terraform output -raw sftp_storage_account_name) --query "isSftpEnabled"
```

---

## 📝 SFTP Connection

### Connection Format:
```bash
sftp <username>.us1bofacssftp@us1bofacssftp.blob.core.windows.net
```

### Create SFTP User:
Use Azure Portal or CLI to create SFTP local users with SSH keys.

---

## 🎯 Benefits of This Approach

✅ **Integrated into main.tf** - No separate files
✅ **Follows your pattern** - Uses modules like your other resources
✅ **Easy to control** - Single variable to enable/disable
✅ **Reusable** - SFTP module can be used for other environments
✅ **Clean** - All in one place

---

## 🔄 Shared Hub (Separate Deployment)

For the shared hub (future):
```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC/terraform

# Deploy shared hub separately
terraform init
terraform plan -var-file="shared-hub.tfvars" \
  -target=azurerm_resource_group.shared_hub_rg \
  -target=azurerm_virtual_network.shared_hub_vnet

terraform apply -var-file="shared-hub.tfvars" -target=azurerm_resource_group.shared_hub_rg
```

**Files for shared hub:**
- `shared-hub-main.tf`
- `shared-hub-variables.tf`
- `shared-hub-outputs.tf`
- `shared-hub.tfvars`

These are independent and can be deployed later when ready to migrate CS Hub.

---

## 📋 Summary

**SFTP is now part of your main infrastructure!**

- Enable/disable with `enable_sftp` variable
- Deployed with your main Terraform apply
- Follows your existing modular pattern
- Clean, simple, maintainable

Ready to deploy! 🎉
