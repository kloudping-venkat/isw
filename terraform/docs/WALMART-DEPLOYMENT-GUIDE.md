# Walmart Networking Deployment Guide

## Overview

This guide explains how to deploy **networking infrastructure only** for the Walmart environment using a **shared hub architecture**.

### Architecture
- **Shared Hub**: Uses existing `US1-BOFA-CS-HUB-VNET` (10.223.40.0/24)
- **Shared VPN Gateway**: Uses existing `US1-BOFA-CS-HUB-VGW`
- **New Walmart Spoke**: Creates `US1-WALMART-PROD-SPOKE-VNET` (10.225.0.0/21)
- **VNet Peering**: Bidirectional peering between Walmart spoke and CS hub

### CIDR Allocation (No Conflicts)

| Environment | Hub CIDR | Spoke CIDR | Notes |
|-------------|----------|------------|-------|
| CS (BOFA) | 10.223.40.0/24 | 10.223.48.0/21 | Existing |
| BAML Dev | 10.224.0.0/24 | 10.224.8.0/21 | Existing |
| BAML Prod | 10.224.16.0/24 | 10.224.24.0/21 | Existing |
| **Walmart** | **Shared CS Hub** | **10.225.0.0/21** | **New - No conflicts!** |

### Walmart Spoke Subnets

| Subnet | CIDR | Purpose |
|--------|------|---------|
| WEB-SUBNET | 10.225.0.0/24 | Web servers (256 IPs) |
| APP-SUBNET | 10.225.1.0/24 | Application servers (256 IPs) |
| DB-SUBNET | 10.225.2.0/24 | Database servers (256 IPs) |
| ADO-SUBNET | 10.225.3.0/24 | Azure DevOps agents (256 IPs) |
| LOGI-SUBNET | 10.225.4.0/24 | AKS/Logi workloads (256 IPs) |
| AG-SUBNET | 10.225.5.0/24 | Application Gateway (256 IPs) |
| SFTP-SUBNET | 10.225.6.0/24 | SFTP services (256 IPs) |
| Reserved | 10.225.7.0/24 | Future expansion (256 IPs) |

## Phase 1: Networking Only Deployment

### Prerequisites

1. **Access Requirements**:
   - Terraform installed (>= 1.5.0)
   - Azure CLI logged in
   - Permissions to:
     - Create resources in subscription
     - Create VNet peering in CS Hub resource group (`US1-BOFA-CS-HUB`)

2. **CS Hub Must Exist**:
   - CS Hub VNet: `US1-BOFA-CS-HUB-VNET`
   - CS Hub Resource Group: `US1-BOFA-CS-HUB`
   - CS VPN Gateway: `US1-BOFA-CS-HUB-VGW`

3. **Get CS Hub VNet ID**:
   ```bash
   # Get the CS Hub VNet resource ID
   az network vnet show \
     --name US1-BOFA-CS-HUB-VNET \
     --resource-group US1-BOFA-CS-HUB \
     --query id -o tsv

   # Example output:
   # /subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/resourceGroups/US1-BOFA-CS-HUB/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-HUB-VNET
   ```

### Step 1: Update Walmart Configuration

Update `terraform/environments/em_bofa/walmart.tfvars`:

```hcl
# Update the shared_hub_vnet_id with your actual subscription ID
shared_hub_vnet_id = "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/US1-BOFA-CS-HUB/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-HUB-VNET"
```

Replace `YOUR_SUBSCRIPTION_ID` with the actual Azure subscription ID from Step 3 above.

### Step 2: Backup and Replace main.tf

**IMPORTANT**: We're temporarily replacing the full main.tf with a networking-only version.

```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC/terraform

# Backup the full configuration
mv main.tf main.tf.fullstack

# Use networking-only configuration
cp main-walmart-networking-only.tf main.tf
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Plan the Deployment

```bash
terraform plan -var-file="environments/em_bofa/walmart.tfvars"
```

**Expected Resources to be Created**:
- ✅ 1 Resource Group: `US1-WALMART-PROD-SPOKE`
- ✅ 1 VNet: `US1-WALMART-PROD-SPOKE-VNET` (10.225.0.0/21)
- ✅ 7 Subnets (WEB, APP, DB, ADO, LOGI, AG, SFTP)
- ✅ 7 Network Security Groups (one per subnet)
- ✅ 1 NAT Gateway for internet connectivity
- ✅ 1 Public IP for NAT Gateway
- ✅ 2 VNet Peerings (Walmart<->CS Hub bidirectional)

**Expected Total**: ~20-25 resources

### Step 5: Review the Plan

Check the plan output carefully:

1. **CIDR Verification**:
   - Spoke VNet: `10.225.0.0/21` ✅
   - Subnets: `10.225.0.0/24` through `10.225.6.0/24` ✅
   - NO overlap with CS (10.223.x.x) ✅

2. **Peering Configuration**:
   - Walmart spoke → CS hub: `use_remote_gateways = true` ✅
   - CS hub → Walmart spoke: `allow_gateway_transit = true` ✅

3. **DNS Configuration**:
   - DNS servers point to CS Hub or Google DNS ✅

### Step 6: Apply the Configuration

```bash
terraform apply -var-file="environments/em_bofa/walmart.tfvars"
```

Type `yes` when prompted.

**Deployment Time**: ~5-10 minutes

### Step 7: Verify Deployment

```bash
# Check Walmart Spoke VNet
az network vnet show \
  --name US1-WALMART-PROD-SPOKE-VNET \
  --resource-group US1-WALMART-PROD-SPOKE

# Check VNet Peering (from Walmart side)
az network vnet peering show \
  --name US1-WALMART-PROD-SPOKE-TO-CS-HUB \
  --resource-group US1-WALMART-PROD-SPOKE \
  --vnet-name US1-WALMART-PROD-SPOKE-VNET \
  --query peeringState

# Check VNet Peering (from CS Hub side)
az network vnet peering show \
  --name CS-HUB-TO-WALMART-SPOKE \
  --resource-group US1-BOFA-CS-HUB \
  --vnet-name US1-BOFA-CS-HUB-VNET \
  --query peeringState

# Expected: "Connected" for both
```

### Step 8: Test Connectivity (After VMs Deployed)

Once VMs are deployed in future phases:

```bash
# From a VM in Walmart spoke, test connectivity to CS hub
ping 10.223.40.130

# Test DNS resolution through hub
nslookup certent.com 10.223.40.130
```

## Phase 2: Compute Resources (Future)

After networking is validated, compute resources can be added:

### Step 1: Restore Full Configuration

```bash
cd /Users/krish/code/isw/em/EM.NextGen-IaC/terraform

# Restore full main.tf
mv main.tf main-walmart-networking-only.tf.used
mv main.tf.fullstack main.tf
```

### Step 2: Update main.tf for Walmart

Uncomment/add Walmart-specific resources:
- Web VMs
- App VMs
- DB VMs
- ADO agents
- AKS cluster (Logi)
- Application Gateway
- SFTP storage

### Step 3: Deploy Incrementally

Deploy one resource group at a time:
1. WEB RG → Web VMs
2. APP RG → App VMs
3. DB RG → Database VMs
4. ADO RG → DevOps agents
5. LOGI RG → AKS cluster
6. SFTP RG → SFTP storage

## Using Azure DevOps Pipeline

### Option 1: Manual Deployment (Recommended for Phase 1)

Use local Terraform commands as described above.

### Option 2: Pipeline Deployment

Once ready, use the multi-env pipeline:

```yaml
Product: em_bofa
Environment: walmart
Action: plan-only  # First run plan
```

After validating plan:

```yaml
Product: em_bofa
Environment: walmart
Action: plan-and-apply  # Apply changes
```

## Troubleshooting

### Error: VNet Peering Permission Denied

```
Error creating VNet Peering: authorization failed
```

**Solution**: Grant permissions to create peering in CS Hub RG:

```bash
az role assignment create \
  --role "Network Contributor" \
  --assignee YOUR_SERVICE_PRINCIPAL_ID \
  --scope /subscriptions/SUBSCRIPTION_ID/resourceGroups/US1-BOFA-CS-HUB
```

### Error: CIDR Overlap

```
Error: address space overlaps with existing VNet
```

**Solution**: Verify Walmart spoke uses `10.225.0.0/21` (not conflicting ranges).

### Error: Cannot Use Remote Gateway

```
Error: cannot use remote gateways while gateway is provisioning
```

**Solution**: Wait for CS Hub VPN Gateway to finish provisioning. Check status:

```bash
az network vnet-gateway show \
  --name US1-BOFA-CS-HUB-VGW \
  --resource-group US1-BOFA-CS-HUB \
  --query provisioningState
```

### Error: Peering Already Exists

```
Error: A peering with name 'CS-HUB-TO-WALMART-SPOKE' already exists
```

**Solution**: Delete existing peering and retry:

```bash
az network vnet peering delete \
  --name CS-HUB-TO-WALMART-SPOKE \
  --resource-group US1-BOFA-CS-HUB \
  --vnet-name US1-BOFA-CS-HUB-VNET
```

## Rollback Procedure

To remove Walmart networking:

```bash
# Destroy Walmart resources
terraform destroy -var-file="environments/em_bofa/walmart.tfvars"

# Or delete manually via Azure Portal/CLI
az group delete --name US1-WALMART-PROD-SPOKE --yes
```

**Note**: Peering in CS Hub RG must be deleted separately if not managed by Terraform.

## Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Walmart Spoke VNet | ✅ Ready | 10.225.0.0/21 - No conflicts |
| VNet Peering | ✅ Ready | Bidirectional with CS Hub |
| Subnets | ✅ Ready | 7 subnets configured |
| NAT Gateway | ✅ Ready | Internet connectivity |
| VPN Access | ✅ Shared | Uses CS Hub VPN Gateway |
| Compute Resources | ⏳ Phase 2 | To be deployed later |

**Next Steps**:
1. Deploy networking (Phase 1)
2. Verify peering and connectivity
3. Plan Phase 2 compute resources
4. Deploy VMs, AKS, and services incrementally

---

**Questions?** Check the main MULTI-ENV-PIPELINE-GUIDE.md or consult the DevOps team.
