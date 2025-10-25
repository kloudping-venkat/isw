# SFTP Optional Features Guide

## Overview

The SFTP module includes optional features that can be enabled when needed. By default, only the core SFTP functionality is deployed.

## Optional Features

### 1. Azure Firewall (~$500/month)
### 2. Automation Account (Free tier + minimal runtime costs)
### 3. SSH Keys (Create manually after deployment)

---

## Current Configuration (Default)

**Deployed:**
- ✅ Storage Account with SFTP
- ✅ Private Endpoint
- ✅ Private DNS Zone
- ✅ NAT Gateway
- ✅ Network Security

**Not Deployed:**
- ❌ Azure Firewall (disabled)
- ❌ Automation Account (disabled)
- ⏳ SSH Keys (create manually)

**Monthly Cost:** ~$80

---

## How to Enable Optional Features

### 🔥 Enable Azure Firewall

**Use Case**: Centralized traffic control, DDoS protection, threat intelligence

**Cost**: ~$500/month + $0.016/GB

#### Step 1: Add AzureFirewallSubnet to Spoke VNet

Update `main.tf` in the `spoke_vnet` module section (around line 96):

```hcl
module "spoke_vnet" {
  # ... existing config ...

  subnets = {
    # ... existing subnets ...

    "AzureFirewallSubnet" = {
      address_prefix    = "10.223.55.0/26"  # Use available address space
      service_endpoints = []
    }
  }
}
```

#### Step 2: Enable Firewall in cs.tfvars

Uncomment in `environments/cs.tfvars`:

```hcl
# Enable Azure Firewall
enable_sftp_firewall = true
```

#### Step 3: Update firewall_subnet_id in main.tf

Update line 206:

```hcl
firewall_subnet_id = module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-AzureFirewallSubnet"]
```

#### Step 4: Apply Changes

```bash
terraform plan -var-file="environments/cs.tfvars"
terraform apply -var-file="environments/cs.tfvars"
```

#### What Gets Created:

- `US1-BOFA-CS-SFTP-FW01` - Azure Firewall
- `US1-BOFA-CS-SFTP-FWPIP01` - Firewall Public IP
- Network rules for SFTP traffic (port 22, 443)

---

### 🤖 Enable Automation Account

**Use Case**: Automated file sync from SFTP to internal SMB shares

**Cost**: Free tier + minimal runtime costs (~$1-5/month)

#### Step 1: Enable Automation in cs.tfvars

Uncomment in `environments/cs.tfvars`:

```hcl
# Enable Automation Account
enable_sftp_automation = true
```

#### Step 2: Configure SMB Destination

Update `main.tf` line 215 with your SMB share path:

```hcl
automation_destination_path = "\\\\fileserver.bofa.local\\sftp\\incoming"
```

#### Step 3: Apply Changes

```bash
terraform plan -var-file="environments/cs.tfvars"
terraform apply -var-file="environments/cs.tfvars"
```

#### What Gets Created:

- `US1-BOFA-CS-SFTP-AUTO` - Automation Account
- `US1-BOFA-CS-SFTP-AUTO-sftp-sync` - PowerShell Runbook
- `US1-BOFA-CS-SFTP-AUTO-schedule` - Hourly Schedule
- Private Endpoint for Automation (optional)
- Private DNS Zone: `privatelink.azure-automation.net`

#### Post-Deployment Configuration:

1. **Store SMB Credentials in Key Vault**:
   ```bash
   az keyvault secret set \
     --vault-name US1-BOFA-CS-SFTP-KV \
     --name "smb-username" \
     --value "domain\\serviceaccount"

   az keyvault secret set \
     --vault-name US1-BOFA-CS-SFTP-KV \
     --name "smb-password" \
     --value "SecurePassword123!"
   ```

2. **Update Runbook with Authentication** (if needed):
   - Go to Azure Portal → Automation Account
   - Edit runbook to include SMB authentication
   - Test runbook manually

3. **Configure Schedule** (optional):
   - Default: Hourly
   - Adjust in Terraform: `automation_schedule_frequency` and `automation_schedule_interval`

---

### 🔑 Create SSH Keys

**Use Case**: User authentication for SFTP access

**Cost**: Free

#### Option 1: Create in Azure Portal

1. Go to Azure Portal
2. Search for "SSH Keys"
3. Create new SSH key:
   - Name: `CS_SFTP_Test`
   - Resource Group: `US1-BOFA-CS-SFTP`
   - Region: East US

#### Option 2: Create via Azure CLI

```bash
# Create SSH key resource in Azure
az sshkey create \
  --name "CS_SFTP_Test" \
  --resource-group US1-BOFA-CS-SFTP \
  --location eastus

# Get public key
az sshkey show \
  --name CS_SFTP_Test \
  --resource-group US1-BOFA-CS-SFTP \
  --query publicKey \
  --output tsv
```

#### Option 3: Use Existing SSH Key

```bash
# Generate locally
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bofa_cs_sftp

# Public key is at: ~/.ssh/bofa_cs_sftp.pub
```

#### Create SFTP User with SSH Key

```bash
# Get public key content
PUBLIC_KEY=$(cat ~/.ssh/bofa_cs_sftp.pub)

# Create SFTP user
az storage account local-user create \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name testuser \
  --home-directory uploads \
  --permission-scope permissions=rcwdl service=blob resource-name=uploads \
  --ssh-authorized-key key="$PUBLIC_KEY"
```

#### Test Connection

```bash
sftp -i ~/.ssh/bofa_cs_sftp testuser.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

---

## Feature Combinations

### Minimal (Current - Default)
```hcl
# No changes needed - already deployed
```
- Core SFTP functionality
- VPN access only
- Manual file management
- **Cost**: ~$80/month

### With Automation (Recommended for Testing Workflows)
```hcl
enable_sftp_automation = true
```
- Core SFTP + automated file sync
- Test Production workflows
- **Cost**: ~$85/month

### With Firewall (Security-Focused)
```hcl
enable_sftp_firewall = true
```
- Core SFTP + centralized security
- DDoS protection
- Threat intelligence
- **Cost**: ~$580/month

### Full Production-Like (All Features)
```hcl
enable_sftp_firewall = true
enable_sftp_automation = true
```
- Complete Production parity
- All features enabled
- **Cost**: ~$585/month

---

## Quick Enable Reference

### To Enable Features:

Edit `terraform/environments/cs.tfvars` and uncomment:

```hcl
# SFTP Optional Features
enable_sftp_firewall = true      # Uncomment to enable Firewall
enable_sftp_automation = true    # Uncomment to enable Automation
```

Then run:
```bash
terraform apply -var-file="environments/cs.tfvars"
```

### To Disable Features:

Comment out or set to `false` in `cs.tfvars`:

```hcl
# enable_sftp_firewall = false    # Disabled
# enable_sftp_automation = false  # Disabled
```

Then run:
```bash
terraform apply -var-file="environments/cs.tfvars"
```

---

## Verification Commands

### Check What's Deployed

```bash
# List all resources in SFTP resource group
az resource list \
  --resource-group US1-BOFA-CS-SFTP \
  --output table

# Check Firewall status
az network firewall show \
  --name US1-BOFA-CS-SFTP-FW01 \
  --resource-group US1-BOFA-CS-SFTP \
  --query provisioningState

# Check Automation Account status
az automation account show \
  --name US1-BOFA-CS-SFTP-AUTO \
  --resource-group US1-BOFA-CS-SFTP \
  --query state
```

### Test SFTP Access

```bash
# Test with SSH key
sftp -i ~/.ssh/bofa_cs_sftp user.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net

# Test with password (if configured)
sftp user.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

---

## Troubleshooting

### Firewall Not Creating

**Error**: `firewall_subnet_id cannot be null`

**Solution**: Add AzureFirewallSubnet to spoke VNet first (see Step 1 above)

### Automation Runbook Fails

**Error**: Access denied to SMB share

**Solution**:
1. Store SMB credentials in Key Vault
2. Grant Automation Account access to Key Vault
3. Update runbook to retrieve credentials

### SSH Key Not Working

**Error**: Permission denied (publickey)

**Solution**:
1. Verify public key is correctly added to user
2. Check private key permissions: `chmod 600 ~/.ssh/private_key`
3. Test with verbose mode: `sftp -vvv -i ~/.ssh/key user.account@endpoint`

---

## Cost Breakdown

| Configuration | Monthly Cost | Components |
|--------------|--------------|------------|
| **Minimal (Current)** | ~$80 | Storage + NAT + PE + DNS |
| **+ Automation** | ~$85 | + Automation Account |
| **+ Firewall** | ~$580 | + Azure Firewall |
| **Full (Both)** | ~$585 | All components |

**Recommendation**: Start with **Minimal**, add **Automation** if needed for testing workflows, add **Firewall** only if security team requires it.

---

## Summary

### Current Deployment
```
✅ SFTP Storage Account
✅ Private Endpoint
✅ NAT Gateway
❌ Azure Firewall (optional, disabled)
❌ Automation Account (optional, disabled)
⏳ SSH Keys (manual creation)
```

### To Match Production Exactly
Uncomment in `cs.tfvars`:
```hcl
enable_sftp_firewall = true
enable_sftp_automation = true
```

Then create SSH keys and SFTP users manually.

---

## Support

- **SFTP Access Guide**: `docs/SFTP-Playbook.md`
- **Access Decision Matrix**: `docs/SFTP-Access-Decision-Matrix.md`
- **Production Comparison**: `PRODUCTION-CS-SFTP-COMPARISON.md`
