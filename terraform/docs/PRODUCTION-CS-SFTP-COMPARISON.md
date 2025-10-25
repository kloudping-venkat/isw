# Production vs CS SFTP Component Comparison

## Production SFTP Components Analysis

### ✅ Components Currently Deployed in CS

| Production Component | CS Equivalent | Status |
|---------------------|---------------|--------|
| `us1bofapsftp` (Storage) | `us1bofacssftpng` (Storage) | ✅ Created |
| `privatelink.blob.core.windows.net` (DNS Zone) | `privatelink.blob.core.windows.net` | ✅ Created |
| `us1bofauatsftp_pe` (Private Endpoint) | `us1bofacssftpng-blob-pe` | ✅ Created |
| `us1bofauatsftp_pe-nic` (NIC) | Auto-created with PE | ✅ Created |
| `US1-BOFA-P-SFTP` (VNet) | `US1-BOFA-CS-SPOKE-VNET` (SFTP-SUBNET) | ✅ Exists |

### ❌ Components MISSING in CS

| Production Component | Purpose | Missing in CS |
|---------------------|---------|---------------|
| **Firewall** | | |
| `US1-BOFA-P-FW01` | Azure Firewall for traffic control | ❌ Not deployed |
| `US1-BOFA-P-FWPIP01` | Firewall Public IP | ❌ Not deployed |
| `US1-BOFA-P-FWMGMT01` | Firewall Management Public IP | ❌ Not deployed |
| `US1-BOFA-P-FWPOLICY01` | Firewall Policy | ❌ Not deployed |
| **Automation** | | |
| `US1-BOFA-P-SFTP-AUTO` | Automation Account | ❌ Not deployed |
| `US1-BOFA-P-SFTP-AUTO-PE1` | Automation Private Endpoint | ❌ Not deployed |
| `privatelink.azure-automation.net` | Automation DNS Zone | ❌ Not deployed |
| `UAT_SFTP_Container_FileShare` | Runbook for file sync | ❌ Not deployed |
| `AzureAutomationTutorial*` | Tutorial runbooks | ❌ Not needed |
| **SSH Keys** | | |
| `ProdIT_SSH_Test` | SSH keys for users | ❌ Not created yet |
| `us1bofauatsftp_bamlimpl_*` | UAT SSH keys | ❌ Not created yet |

### ⚠️ Different Architecture

Production has:
- **Dedicated VNet**: `US1-BOFA-P-SFTP` (entire VNet for SFTP)
- **Azure Firewall**: Centralized traffic control
- **Automation Account**: Automated file movement to SMB shares

CS has:
- **Subnet in Spoke VNet**: `SFTP-SUBNET` in `US1-BOFA-CS-SPOKE-VNET`
- **NAT Gateway**: Instead of Firewall (simpler, lower cost)
- **No Automation**: Manual file management

---

## Should CS Match Production Exactly?

### 🤔 Decision Points

#### 1. Azure Firewall

**Production has**: `US1-BOFA-P-FW01` + Policy + 2 Public IPs
**CS has**: NAT Gateway only

**Cost**:
- Firewall: ~$500/month + $0.016/GB processed
- NAT Gateway: ~$32/month + $0.045/GB outbound

**Recommendation**:
- ⚠️ **CS is lower environment** - NAT Gateway is sufficient
- ✅ **Production needs Firewall** for compliance/security policies
- 💡 **Add Firewall to CS only if**: Security team requires it

#### 2. Automation Account

**Production has**:
- Automation Account
- Runbooks for SFTP→SMB sync
- Private Endpoint for Automation

**CS has**: None

**Use Case**: Automatically move files from SFTP to internal SMB file shares

**Recommendation**:
- ❌ **CS probably doesn't need automation** - manual/testing workflows
- ✅ **Enable if**: CS needs to replicate Production file flows
- 💰 **Cost**: ~$0 (free tier) + minimal for runbook execution

#### 3. SSH Keys

**Production has**: Multiple SSH keys for different users/partners

**CS has**: None (not created yet)

**Recommendation**:
- ✅ **Create after infrastructure deployment**
- ✅ **Use separate keys for CS** (don't reuse Production keys)
- ✅ **Fewer users in CS** (only test accounts needed)

---

## Recommended CS Configuration

### Option A: Minimal CS (Current - Recommended for Dev/Test)

```
✅ Storage Account (us1bofacssftpng)
✅ Private Endpoint
✅ Private DNS Zone (blob)
✅ NAT Gateway (outbound connectivity)
✅ NSG (basic security)
❌ Azure Firewall (use NAT Gateway instead)
❌ Automation Account (manual testing)
❌ Dedicated SFTP VNet (use SFTP-SUBNET in Spoke)
```

**Best for**: Dev/test environment, cost-effective, simpler architecture

### Option B: Production-Like CS (Match Production)

```
✅ Storage Account (us1bofacssftpng)
✅ Private Endpoint
✅ Private DNS Zone (blob)
✅ Private DNS Zone (automation)
✅ Azure Firewall (US1-BOFA-CS-FW01)
✅ Automation Account (US1-BOFA-CS-SFTP-AUTO)
✅ Automation Private Endpoint
✅ Runbooks (file sync to SMB)
⚠️ Dedicated SFTP VNet (optional)
```

**Best for**: CS environment that closely mirrors Production, testing Production workflows

---

## How to Add Missing Components to CS

### Enable Azure Firewall

Update `main.tf`:
```hcl
module "sftp" {
  # ... existing config ...

  # Azure Firewall
  create_firewall      = true
  firewall_name        = "US1-BOFA-CS-FW01"
  firewall_pip_name    = "US1-BOFA-CS-FWPIP01"
  firewall_sku_tier    = "Standard"
  firewall_subnet_id   = module.spoke_vnet.subnet_ids["AzureFirewallSubnet"]  # Must create this subnet

  # Firewall Policy (optional)
  firewall_policy_id   = azurerm_firewall_policy.cs_sftp_policy.id
}
```

**Prerequisites**:
1. Create `AzureFirewallSubnet` in Spoke VNet (must be /26 or larger)
2. Create Firewall Policy (or use null for basic rules)

### Enable Automation Account

Update `main.tf`:
```hcl
module "sftp" {
  # ... existing config ...

  # Automation
  create_automation_account    = true
  automation_account_name      = "US1-BOFA-CS-SFTP-AUTO"
  enable_automation_schedule   = true
  automation_schedule_frequency = "Hour"
  automation_schedule_interval = 4
  automation_source_container  = "uploads"
  automation_destination_path  = "\\\\fileserver\\sftp\\incoming"

  # Need to provide custom runbook content or use default
  sftp_sync_runbook_content    = ""  # Uses default PowerShell script
}
```

**Prerequisites**:
1. SMB file server accessible from Azure
2. Credentials stored in Key Vault
3. Runbook configured with authentication

### Create SSH Keys

After infrastructure is deployed:

```bash
# Create test user SSH keys
az sshkey create \
  --name "CS_SFTP_Test" \
  --resource-group US1-BOFA-CS-SFTP \
  --location eastus

# Create SFTP user with SSH key
az storage account local-user create \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name testuser \
  --home-directory uploads \
  --permission-scope permissions=rcwdl service=blob resource-name=uploads \
  --ssh-authorized-key key="$(az sshkey show --name CS_SFTP_Test --resource-group US1-BOFA-CS-SFTP --query publicKey -o tsv)"
```

---

## Component Comparison Table

| Component | Production | CS Current | CS with Full Features |
|-----------|-----------|------------|----------------------|
| **Storage Account** | ✅ us1bofapsftp | ✅ us1bofacssftpng | ✅ us1bofacssftpng |
| **Private Endpoint** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Private DNS (Blob)** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Private DNS (Automation)** | ✅ Yes | ❌ No | ✅ Yes |
| **NAT Gateway** | ❓ Unknown | ✅ Yes | ✅ Yes |
| **Azure Firewall** | ✅ Yes | ❌ No | ✅ Optional |
| **Firewall Policy** | ✅ Yes | ❌ No | ✅ Optional |
| **Automation Account** | ✅ Yes | ❌ No | ✅ Optional |
| **Automation PE** | ✅ Yes | ❌ No | ✅ Optional |
| **Runbooks** | ✅ 2+ | ❌ No | ✅ Optional |
| **SSH Keys** | ✅ Multiple | ⏳ Create later | ⏳ Create later |
| **Dedicated VNet** | ✅ Yes | ❌ No (uses Spoke) | ❌ No (Spoke is fine) |

---

## Cost Comparison

### Current CS Configuration (Minimal)
| Component | Monthly Cost |
|-----------|--------------|
| Storage Account (GRS, HNS) | ~$40 (1TB) |
| NAT Gateway | ~$32 + data |
| Private Endpoint | ~$7 |
| Private DNS Zone | ~$0.50 |
| **Total** | **~$80/month** |

### Production-Like CS Configuration (Full)
| Component | Monthly Cost |
|-----------|--------------|
| Storage Account (GRS, HNS) | ~$40 (1TB) |
| NAT Gateway | ~$32 + data |
| Private Endpoint (Blob) | ~$7 |
| Private Endpoint (Automation) | ~$7 |
| Private DNS Zones (2) | ~$1 |
| **Azure Firewall** | **~$500 + data** |
| Automation Account | ~$0 (free tier) |
| **Total** | **~$587/month** |

**Cost difference**: +$507/month for Firewall

---

## Recommendations by Scenario

### Scenario 1: CS is for Testing Only
**Use**: Current minimal configuration ✅
**Skip**: Firewall, Automation
**Reasoning**: Cost-effective, sufficient for testing SFTP functionality

### Scenario 2: CS Must Mirror Production Workflows
**Use**: Production-like configuration
**Add**: Automation Account, Runbooks, Automation PE
**Consider**: Azure Firewall (if budget allows)
**Reasoning**: Test end-to-end workflows including file sync

### Scenario 3: CS is Pre-Production / Staging
**Use**: Full Production-like configuration
**Add**: Everything Production has
**Reasoning**: Final validation before Production release

---

## What We Have vs What Production Has

### ✅ We Already Have (Good Enough for CS)
1. Storage Account with SFTP enabled
2. Private Endpoint (secure access)
3. Private DNS Zone for blob storage
4. NAT Gateway (outbound connectivity)
5. Network isolation (SFTP-SUBNET)
6. Soft delete and retention policies
7. GRS replication (redundancy)

### ❌ Missing from Production (Can Add If Needed)
1. Azure Firewall (expensive, might not need for CS)
2. Automation Account (can add if needed for testing)
3. Dedicated SFTP VNet (CS uses shared Spoke - more efficient)
4. SSH Keys (create after deployment)

### 💡 Recommendation
**For CS environment**: Current configuration is sufficient.
**Add Automation** only if you need to test file sync workflows.
**Skip Firewall** unless security team requires it for compliance.

---

## Action Items

### Now (During Initial Deployment)
- [x] Deploy Storage Account
- [x] Deploy Private Endpoint
- [x] Deploy Private DNS Zone
- [x] Deploy NAT Gateway
- [ ] Complete deployment
- [ ] Lock down network (change to "Deny")

### After Deployment (If Needed)
- [ ] Create SSH keys for test users
- [ ] Create SFTP users with appropriate permissions
- [ ] Test SFTP connectivity from VPN
- [ ] Document test procedures

### Optional (Based on Requirements)
- [ ] Add Automation Account if file sync testing needed
- [ ] Add Azure Firewall if security team requires it
- [ ] Create runbooks for automated file processing
- [ ] Set up monitoring and alerting

---

## Summary

**Current CS SFTP**: ✅ Production-ready for basic SFTP file transfer
**Missing**: Automation and Firewall (luxury features, not essential for CS)
**Recommendation**: Deploy current configuration, add Automation/Firewall only if specific use cases require them

The CS environment has the **core SFTP functionality** that Production has. The missing components (Firewall, Automation) are **operational enhancements** that can be added later if needed.
