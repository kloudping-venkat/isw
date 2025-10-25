# Quick Start Example for Custom Import

## For Your Current Issue
Based on your earlier errors, here's the exact format you would use:

### Pipeline Parameter Value:
```
module.spoke_vnet.module.nat_gateway[0].azurerm_subnet_nat_gateway_association.subnet_association["4"]|/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SPOKE/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-SPOKE-VNET/subnets/US1-BOFA-CS-SPOKE-ADO-SUBNET,module.spoke_vnet.module.vnet_peering[0].azurerm_virtual_network_peering.local_to_aadds|/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SPOKE/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-SPOKE-VNET/virtualNetworkPeerings/US1-BOFA-CS-SPOKE-VNET-to-US1-BOFA-P-DS-VNET,module.spoke_vnet.module.vnet_peering[0].azurerm_virtual_network_peering.aadds_to_local|/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-P-DS/providers/Microsoft.Network/virtualNetworks/US1-BOFA-P-DS-VNET/virtualNetworkPeerings/US1-BOFA-P-DS-VNET-to-US1-BOFA-CS-SPOKE-VNET
```

### Steps:
1. Go to your Azure DevOps pipeline
2. Click "Run pipeline"
3. Set parameters:
   - `action`: **plan-and-apply**
   - `importResources`: **false**
   - `customImportList`: **paste the above line**
4. Run the pipeline

## Future Usage
For any other resources you need to import:

1. Create a text file with your terraform import commands:
```bash
# my_imports.txt
terraform import 'module.example.azurerm_resource.name' '/subscriptions/.../resource-id'
terraform import 'azurerm_resource_group.main' '/subscriptions/.../resourceGroups/rg-name'
```

2. Use the helper script:
```bash
./format_imports.sh my_imports.txt
```

3. Copy the output into the pipeline parameter

## Benefits of This Approach
- ✅ **Flexible**: Import any resources without changing pipeline code
- ✅ **Reusable**: Same parameter works for different resource types
- ✅ **Safe**: Includes validation and error handling
- ✅ **Temporary**: Just clear the parameter after successful import