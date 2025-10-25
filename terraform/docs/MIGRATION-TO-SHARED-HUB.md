# Migration Plan: CS Hub to Shared Hub Architecture

## Overview
This document outlines the migration from individual environment hubs to a centralized Shared Hub model, allowing multiple spoke environments (CS, Production, UAT) to share common infrastructure like VPN Gateway, Bastion, and Azure Firewall.

## Current Architecture (CS Environment)

```
┌─────────────────────────────────────┐
│ CS-HUB-VNET (10.223.40.0/24)       │
│ ├── VPN Gateway                     │
│ ├── Azure Bastion                   │
│ └── Hub subnets                     │
└──────────────┬──────────────────────┘
               │ VNet Peering
               ▼
┌─────────────────────────────────────┐
│ CS-SPOKE-VNET (10.223.48.0/21)     │
│ ├── WEB-SUBNET                      │
│ ├── APP-SUBNET                      │
│ ├── DB-SUBNET                       │
│ ├── ADO-SUBNET                      │
│ ├── LOGI-SUBNET                     │
│ ├── AG-SUBNET                       │
│ └── SFTP-SUBNET                     │
└─────────────────────────────────────┘
```

## Target Architecture (Shared Hub Model)

```
┌──────────────────────────────────────────────┐
│ SHARED-HUB-VNET (10.223.0.0/22)             │
│ ├── VPN Gateway (shared)                    │
│ ├── Azure Bastion (shared)                  │
│ ├── Azure Firewall (centralized security)   │
│ ├── Shared Services Subnet                  │
│ └── Management Subnet                       │
└───────────┬──────────────────────────────────┘
            │
            ├─── Peering ───┬─────────────────────────┐
            │               │                         │
            ▼               ▼                         ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ CS-SPOKE         │ │ P-SPOKE          │ │ UAT-SPOKE        │
│ (10.223.48.0/21) │ │ (10.223.56.0/21) │ │ (10.223.64.0/21) │
│                  │ │                  │ │                  │
│ App workloads    │ │ Production       │ │ Testing          │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

## Benefits of Migration

### Cost Savings
- **Single VPN Gateway**: ~$200-500/month saved per environment
- **Single Bastion**: ~$140/month saved per environment
- **Shared Firewall**: Centralized licensing and management

### Operational Efficiency
- **Single point of management** for VPN users and certificates
- **Centralized security policies** via Azure Firewall
- **Simplified DNS management** with shared Private DNS zones
- **Easier compliance** with centralized logging

### Scalability
- Add new environments (UAT, QA, DR) without duplicating hub infrastructure
- Consistent network architecture across all environments
- Easier to implement hub-level services (NVA, monitoring, etc.)

## Migration Strategy

### Phase 1: Deploy Shared Hub (Parallel - No Impact)
**Timeline**: Week 1
**Risk**: None (new infrastructure)

1. **Deploy Shared Hub** using existing `shared-hub.tfvars`:
   ```bash
   terraform apply -var-file="shared-hub.tfvars"
   ```

2. **Resources Created**:
   - SHARED-HUB-VNET (10.223.0.0/22)
   - VPN Gateway in shared hub
   - Azure Bastion in shared hub
   - Private DNS zones
   - Firewall (optional)

3. **Validation**:
   - Test VPN connectivity to shared hub
   - Verify Bastion access
   - No impact to CS environment

### Phase 2: Establish Peering (Low Risk)
**Timeline**: Week 2
**Risk**: Low (additive change)

1. **Create VNet Peering** from Shared Hub to CS-SPOKE:
   ```hcl
   resource "azurerm_virtual_network_peering" "shared_hub_to_cs_spoke" {
     name                         = "SHARED-HUB-TO-CS-SPOKE"
     resource_group_name          = "US1-EM-SHARED-HUB-RG01"
     virtual_network_name         = "US1-EM-SHARED-HUB-VNET"
     remote_virtual_network_id    = module.spoke_vnet.vnet_id
     allow_virtual_network_access = true
     allow_forwarded_traffic      = true
     allow_gateway_transit        = true
     use_remote_gateways          = false
   }

   resource "azurerm_virtual_network_peering" "cs_spoke_to_shared_hub" {
     name                         = "CS-SPOKE-TO-SHARED-HUB"
     resource_group_name          = "US1-BOFA-CS-SPOKE"
     virtual_network_name         = "US1-BOFA-CS-SPOKE-VNET"
     remote_virtual_network_id    = azurerm_virtual_network.shared_hub_vnet.id
     allow_virtual_network_access = true
     allow_forwarded_traffic      = true
     allow_gateway_transit        = false
     use_remote_gateways          = true  # Use shared hub gateway
   }
   ```

2. **Update Route Tables** (if needed):
   - Add routes to shared hub gateway
   - Update UDRs for spoke subnets

3. **Validation**:
   - Test connectivity between CS-SPOKE and Shared Hub
   - Verify VMs in CS-SPOKE can reach shared services
   - Test VPN connectivity through shared gateway

### Phase 3: Migrate VPN Users (Medium Risk)
**Timeline**: Week 3
**Risk**: Medium (user impact during migration)

1. **Preparation**:
   - Export VPN user configurations from CS-HUB Gateway
   - Document all VPN client settings
   - Communicate migration window to users

2. **Migration**:
   - Add VPN users to Shared Hub Gateway
   - Update Azure AD authentication settings
   - Distribute new VPN client configuration files

3. **Testing**:
   - Test VPN connectivity through shared hub
   - Verify access to CS-SPOKE resources
   - Validate split-tunnel settings

4. **Cutover**:
   - Schedule maintenance window (e.g., Saturday 2-4 AM)
   - Users download new VPN profiles
   - Verify connectivity

### Phase 4: Update CS Spoke Peering (Low Risk)
**Timeline**: Week 4
**Risk**: Low (configuration change)

1. **Update CS-SPOKE to Shared Hub Peering**:
   - Modify peering to use shared hub gateway
   - Remove dependency on CS-HUB gateway

2. **Update in main.tf**:
   ```hcl
   # Remove old CS-HUB to CS-SPOKE peering
   # resource "azurerm_virtual_network_peering" "hub_to_spoke" { ... }
   # resource "azurerm_virtual_network_peering" "spoke_to_hub" { ... }

   # Add new SHARED-HUB to CS-SPOKE peering
   # (Keep peering configurations from Phase 2)
   ```

3. **Validation**:
   - Verify all connectivity still works
   - Test VPN → CS-SPOKE access
   - Test inter-subnet communication

### Phase 5: Decommission CS Hub (Final Cleanup)
**Timeline**: Week 5-6
**Risk**: Low (removal of unused resources)

1. **Verify CS-HUB is Not in Use**:
   - Check VNet peering shows no traffic
   - Verify gateway is idle
   - Confirm Bastion not used

2. **Remove CS-HUB Resources**:
   ```bash
   # Remove from Terraform state
   terraform state rm module.hub_infrastructure

   # Or comment out in main.tf:
   # module "hub_infrastructure" { ... }
   ```

3. **Delete Azure Resources**:
   - Delete CS-HUB VNet peering
   - Delete VPN Gateway (save ~$200-500/month)
   - Delete Bastion (save ~$140/month)
   - Delete CS-HUB-VNET
   - Delete CS-HUB resource group

4. **Update Documentation**:
   - Update architecture diagrams
   - Update runbooks
   - Update disaster recovery procedures

## Rollback Plan

### If Issues Occur During Migration

**Before Phase 4 Complete**:
- CS-HUB still exists and functional
- Simply revert peering changes
- Users reconnect to CS-HUB VPN
- No data loss, minimal downtime

**After Phase 5 (CS-HUB Deleted)**:
- Redeploy CS-HUB from Terraform state backup
- Takes ~30-45 minutes for gateway deployment
- Restore VPN configurations from backup
- Re-establish peering

## Testing Checklist

- [ ] VPN connectivity through shared hub
- [ ] Bastion access to CS-SPOKE VMs
- [ ] VM-to-VM communication within CS-SPOKE
- [ ] CS-SPOKE to internet connectivity (NAT Gateway)
- [ ] Private endpoint connectivity (SFTP, Key Vault)
- [ ] DNS resolution (Private DNS zones)
- [ ] Application Gateway functionality
- [ ] AKS cluster connectivity (when enabled)
- [ ] Azure DevOps agent connectivity
- [ ] Database connectivity from APP tier

## Cost Comparison

### Current (CS with Own Hub)
| Resource | Monthly Cost |
|----------|--------------|
| CS-HUB VPN Gateway (VpnGw2) | ~$350 |
| CS-HUB Bastion | ~$140 |
| CS-HUB VNet | ~$0 |
| **CS Hub Total** | **~$490/month** |

### After Migration (Shared Hub)
| Resource | Monthly Cost | Shared Across |
|----------|--------------|---------------|
| Shared VPN Gateway (VpnGw2) | ~$350 | All environments |
| Shared Bastion | ~$140 | All environments |
| Shared Firewall (optional) | ~$500 | All environments |
| **Shared Hub Total** | **~$990/month** | 3+ environments |
| **Cost per Environment** | **~$330/month** | (vs $490 standalone) |
| **Savings per Environment** | **$160/month** | **$1,920/year** |

With 3 environments (CS, P, UAT):
- **Old Model**: 3 × $490 = $1,470/month
- **New Model**: $990/month (shared hub)
- **Total Savings**: $480/month = **$5,760/year**

## Timeline Summary

| Week | Phase | Activity | Downtime |
|------|-------|----------|----------|
| 1 | Phase 1 | Deploy Shared Hub | None |
| 2 | Phase 2 | Establish Peering | None |
| 3 | Phase 3 | Migrate VPN Users | 1-2 hours |
| 4 | Phase 4 | Update Peering Config | None |
| 5-6 | Phase 5 | Decommission CS-HUB | None |

**Total Project Duration**: 6 weeks
**Total User-Facing Downtime**: 1-2 hours (VPN migration only)

## Pre-Requisites

- [ ] Shared hub deployed and tested
- [ ] VPN users notified of migration
- [ ] Backup of current CS-HUB configuration
- [ ] Terraform state backup
- [ ] Change request approved
- [ ] Maintenance window scheduled
- [ ] Rollback plan validated

## Success Criteria

- [ ] All CS-SPOKE resources accessible via VPN
- [ ] No increase in latency
- [ ] All applications functioning normally
- [ ] Cost savings realized
- [ ] CS-HUB successfully decommissioned
- [ ] Documentation updated
- [ ] Team trained on new architecture

## References

- Azure Hub-Spoke Architecture: https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
- VNet Peering Documentation: https://docs.microsoft.com/azure/virtual-network/virtual-network-peering-overview
- VPN Gateway Migration Guide: https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-migration

## Notes

- This migration is **non-destructive** until Phase 5
- Can pause at any phase to validate
- Each spoke environment (CS, P, UAT) remains independent
- Only shared services are centralized
- Application data and workloads stay in spoke VNets
