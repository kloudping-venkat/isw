# Walmart Networking - Quick Start

## What Was Configured

✅ **Walmart Spoke VNet**: `10.225.0.0/21` (NO CIDR conflicts)
✅ **Shared CS Hub**: Uses existing `US1-BOFA-CS-HUB-VNET` and VPN Gateway
✅ **VNet Peering**: Bidirectional peering configured
✅ **Networking Only**: All compute resources commented out (Phase 2)

## Files Created/Modified

### New Files
1. `main-walmart-networking-only.tf` - Walmart-specific networking configuration
2. `WALMART-DEPLOYMENT-GUIDE.md` - Complete deployment guide
3. `WALMART-QUICK-START.md` - This file

### Modified Files
1. `environments/em_bofa/walmart.tfvars` - Updated with:
   - Unique CIDR: `10.225.0.0/21`
   - Shared hub configuration
   - DNS servers pointing to CS hub
   - Cleaned up unused variables

2. `variables.tf` - Added:
   - `use_shared_hub`
   - `shared_hub_vnet_name`
   - `shared_hub_vnet_resource_group`
   - `shared_hub_vnet_id`

## CIDR Summary (No Conflicts!)

```
CS (BOFA):  10.223.40.0/24 (hub) + 10.223.48.0/21 (spoke)
BAML Dev:   10.224.0.0/24 (hub) + 10.224.8.0/21 (spoke)
BAML Prod:  10.224.16.0/24 (hub) + 10.224.24.0/21 (spoke)
Walmart:    Shared CS Hub + 10.225.0.0/21 (spoke) ← New!
```

## Before You Deploy

### 1. Get CS Hub VNet ID

```bash
az network vnet show \
  --name US1-BOFA-CS-HUB-VNET \
  --resource-group US1-BOFA-CS-HUB \
  --query id -o tsv
```

### 2. Update walmart.tfvars

Edit `environments/em_bofa/walmart.tfvars` line 18:

```hcl
shared_hub_vnet_id = "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/US1-BOFA-CS-HUB/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-HUB-VNET"
```

Replace `YOUR_SUBSCRIPTION_ID` with actual ID.

## Deploy Networking

### Method 1: Local Terraform (Recommended for initial deployment)

```bash
cd terraform

# Backup full config
mv main.tf main.tf.fullstack

# Use networking-only config
cp main-walmart-networking-only.tf main.tf

# Initialize
terraform init

# Plan
terraform plan -var-file="environments/em_bofa/walmart.tfvars"

# Apply (if plan looks good)
terraform apply -var-file="environments/em_bofa/walmart.tfvars"
```

### Method 2: Azure DevOps Pipeline

```yaml
Pipeline: multi-env-pipeline.yml
Product: em_bofa
Environment: walmart
Action: plan-only
```

## Verify Deployment

```bash
# Check peering status (should be "Connected")
az network vnet peering show \
  --name US1-WALMART-PROD-SPOKE-TO-CS-HUB \
  --resource-group US1-WALMART-PROD-SPOKE \
  --vnet-name US1-WALMART-PROD-SPOKE-VNET \
  --query peeringState -o tsv
```

## What Gets Created

- ✅ Resource Group: `US1-WALMART-PROD-SPOKE`
- ✅ VNet: `US1-WALMART-PROD-SPOKE-VNET`
- ✅ 7 Subnets (WEB, APP, DB, ADO, LOGI, AG, SFTP)
- ✅ 7 Network Security Groups
- ✅ 1 NAT Gateway + Public IP
- ✅ 2 VNet Peerings (bidirectional)

**Total**: ~20-25 resources, **No VMs or compute resources**

## What's NOT Created (Phase 2)

- ❌ Hub VNet (using shared CS hub)
- ❌ VPN Gateway (using shared CS VPN gateway)
- ❌ Virtual Machines (web, app, db, ado)
- ❌ AKS Cluster (Logi)
- ❌ Application Gateway
- ❌ SFTP Storage
- ❌ Key Vaults
- ❌ AADDS Peering (using CS hub connectivity)

## Key Benefits

1. **Cost Savings**: No duplicate hub infrastructure or VPN gateway
2. **Shared VPN**: Walmart users connect via CS VPN gateway
3. **Isolated Workloads**: Walmart spoke is separate from CS spoke
4. **No CIDR Conflicts**: `10.225.x.x` range doesn't overlap
5. **Clean Architecture**: Proper hub-spoke design

## Network Diagram

```
                    ┌─────────────────────────┐
                    │   CS Hub VNet           │
                    │   10.223.40.0/24        │
                    │                         │
                    │  ┌─────────────────┐    │
                    │  │  VPN Gateway    │    │
                    │  │ (Shared by both)│    │
                    │  └─────────────────┘    │
                    └───────┬────────┬────────┘
                            │        │
                Peering     │        │      Peering
                            │        │
              ┌─────────────┘        └─────────────┐
              │                                     │
    ┌─────────▼──────────┐            ┌───────────▼─────────┐
    │  CS Spoke VNet     │            │ Walmart Spoke VNet   │
    │  10.223.48.0/21    │            │  10.225.0.0/21       │
    │                    │            │                      │
    │  - Web Servers     │            │  - Web Servers       │
    │  - App Servers     │            │  - App Servers       │
    │  - DB Servers      │            │  - DB Servers        │
    │  - AKS/Logi        │            │  - AKS/Logi          │
    └────────────────────┘            └──────────────────────┘
```

## Next Steps

1. ✅ Deploy Walmart networking (Phase 1) ← You are here
2. ⏳ Verify connectivity and peering
3. ⏳ Plan Phase 2 compute resources
4. ⏳ Deploy VMs incrementally
5. ⏳ Deploy AKS cluster
6. ⏳ Configure Application Gateway
7. ⏳ Test end-to-end connectivity

## Need Help?

- Full guide: `WALMART-DEPLOYMENT-GUIDE.md`
- Pipeline guide: `../pipelines/MULTI-ENV-PIPELINE-GUIDE.md`
- Backend config: `../pipelines/BACKEND-CONFIGURATION.md`

---

**Ready to deploy!** 🚀
