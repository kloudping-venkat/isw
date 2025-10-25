# Custom Terraform Import Pipeline Feature

## Overview
The pipeline now supports importing any Terraform resources via a flexible input parameter, allowing you to import resources dynamically without modifying pipeline code.

## New Pipeline Parameters

### `customImportList`
- **Type**: String
- **Default**: Empty
- **Format**: `terraform_address|azure_resource_id,terraform_address2|azure_resource_id2`
- **Description**: Comma-separated list of resources to import before terraform apply

## Usage Examples

### Example 1: Single Resource Import
```
module.spoke_vnet.azurerm_subnet.example|/subscriptions/12345/resourceGroups/rg-name/providers/Microsoft.Network/virtualNetworks/vnet-name/subnets/subnet-name
```

### Example 2: Multiple Resources Import
```
module.spoke_vnet.azurerm_subnet.web|/subscriptions/12345/.../subnets/web-subnet,module.hub.azurerm_virtual_network_gateway.main|/subscriptions/12345/.../virtualNetworkGateways/gateway-name
```

### Example 3: Real Import Cases
```
module.spoke_vnet.module.nat_gateway[0].azurerm_subnet_nat_gateway_association.subnet_association["4"]|/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SPOKE/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-SPOKE-VNET/subnets/US1-BOFA-CS-SPOKE-ADO-SUBNET,module.spoke_vnet.module.vnet_peering[0].azurerm_virtual_network_peering.local_to_aadds|/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SPOKE/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-SPOKE-VNET/virtualNetworkPeerings/US1-BOFA-CS-SPOKE-VNET-to-US1-BOFA-P-DS-VNET
```

## How to Use

### Method 1: Pipeline UI
1. Run your Azure DevOps pipeline
2. In the parameters screen:
   - Set `action` to `plan-and-apply`
   - Paste your formatted import list into `Custom Import List`
   - Set `importResources` to `false` (unless you want both)
3. Run the pipeline

### Method 2: Helper Script
Use the provided helper script to convert terraform import commands:

```bash
# Interactive mode
./format_imports.sh

# File mode  
./format_imports.sh my_imports.txt
```

#### Example input file (`my_imports.txt`):
```bash
terraform import 'module.example.azurerm_subnet.main' '/subscriptions/.../subnets/subnet-name'
terraform import 'azurerm_resource_group.example' '/subscriptions/.../resourceGroups/rg-name'
```

## Format Requirements

### Resource Address Format
- Use single quotes around complex addresses with special characters
- Examples:
  - `module.spoke_vnet.azurerm_subnet.web`
  - `module.hub.module.vpn[0].azurerm_virtual_network_gateway.main`
  - `azurerm_resource_group.example`

### Azure Resource ID Format
- Full ARM resource ID path
- Format: `/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/{provider}/{resource-type}/{resource-name}`
- For nested resources: `/subscriptions/.../resourceGroups/.../providers/.../parentResource/parent-name/childResource/child-name`

## Pipeline Behavior

### Import Step Execution
- Runs only when `customImportList` is not empty
- Executes before terraform apply
- Uses the same tfvars file as plan/apply operations
- Provides detailed logging for each import operation

### Error Handling
- ✅ **Success**: Resource imported successfully
- ⚠️ **Already exists**: Resource already in state (expected for subsequent runs)
- ❌ **Failed**: Invalid address or resource ID

### Safe Operation
- Import never modifies existing Azure resources
- Only adds resources to Terraform state
- Failed imports don't stop the pipeline (continues with other imports)
- Always runs terraform plan after imports to verify state

## Integration with Existing Features

### Compatibility
- ✅ Works alongside the existing `importResources` boolean parameter
- ✅ Can be used with both parameters simultaneously
- ✅ Supports all environments (cs, dev, prod, etc.)

## Best Practices

### Import Workflow
1. **First Run** (Import):
   - Set `customImportList` with your resources
   - Set `action` to `plan-and-apply`
   - Run pipeline

2. **Subsequent Runs** (Normal Operations):
   - ⚠️ **IMPORTANT**: Set `customImportList` to `""` (empty)
   - Set `action` to `plan-and-apply`
   - Run pipeline

### Why Clear the Import List?
- ✅ **Prevents re-import attempts** of already imported resources
- ✅ **Faster pipeline execution** (skips import step)
- ✅ **Cleaner logs** without unnecessary import warnings
- ✅ **Best practice** for terraform state management

## Files Modified/Created
- `pipelines/cs-azure-pipeline.yml` - Added customImportList parameter
- `pipelines/templates/custom-import.yml` - New flexible import template
- `format_imports.sh` - Helper script for formatting import commands
- `CUSTOM_IMPORT_DOCS.md` - This documentation

## Troubleshooting

### Common Issues
1. **Invalid format error**: Check that you're using `|` separator and proper comma separation
2. **Resource not found**: Verify the Azure resource ID is correct and accessible
3. **Permission errors**: Ensure service principal has read access to the resources
4. **Already in state**: This is expected for subsequent runs - not an error

### Getting Resource IDs
```bash
# Find resource ID using Azure CLI
az resource show --name "resource-name" --resource-group "rg-name" --resource-type "Microsoft.Network/virtualNetworks" --query id --output tsv
```

This feature provides maximum flexibility for importing any Terraform resources without pipeline code changes!