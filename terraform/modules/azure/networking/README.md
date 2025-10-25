# EM NextGen Networking Module

## Overview

This networking module implements a hybrid approach combining the official **Azure VNet Terraform module** with custom direct resources to achieve optimal balance between standardization and flexibility.

## Architecture Approach

### 🎯 Hybrid Strategy

**Azure Module Components** (`Azure/vnet/azurerm`):
- Virtual Network creation and management
- Basic subnet provisioning with address spaces
- Service endpoints configuration
- Standard resource tagging

**Direct Terraform Resources**:
- Custom Network Security Groups (NSGs)
- Advanced security rules for VNet traffic control
- NSG-subnet associations

## Benefits

### ✅ Advantages of Using Azure Network Module

1. **Standardization & Best Practices**
   - Follows Microsoft's recommended patterns
   - Regularly updated with latest Azure features
   - Consistent resource naming conventions

2. **Reduced Code Maintenance**
   - Less custom code to maintain
   - Automatic updates with new module versions
   - Built-in validation and error handling

3. **Improved Reliability**
   - Battle-tested module used across many deployments
   - Comprehensive testing by Microsoft and community
   - Handles edge cases and Azure API quirks

4. **Enhanced Documentation**
   - Well-documented input variables and outputs
   - Examples and usage patterns available
   - Community support and contributions

5. **Faster Development**
   - Simplified VNet and subnet creation
   - Built-in service endpoint management
   - Reduced boilerplate code

### 🔧 When Direct Resources Are Needed

**Custom Security Requirements**:
- Specific NSG rules for organizational compliance
- Advanced traffic filtering between subnets
- Custom security rule priorities and protocols

**Advanced Networking Features**:
- Custom route tables with specific routes
- Network peering with specific configurations
- Advanced subnet delegations

## Implementation Details

### Module Usage
```hcl
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "~> 4.0"

  resource_group_name = var.rg_name
  vnet_location       = var.location
  vnet_name           = var.vnet_name
  address_space       = var.vnet_address_space

  subnet_prefixes = [for subnet in var.subnets : subnet.address_prefix]
  subnet_names    = [for name, subnet in var.subnets : name]

  subnet_service_endpoints = {
    for name, subnet in var.subnets : name => lookup(subnet, "service_endpoints", [])
  }

  tags = var.tags
}
```

### Custom NSG Rules
```hcl
resource "azurerm_network_security_rule" "allow_vnet_inbound" {
  for_each = var.subnets

  name                        = "AllowVnetInBound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg[each.key].name
}
```

## Resource Coverage

| Resource Type | Azure Module | Direct Resource | Reason |
|---------------|--------------|-----------------|---------|
| Virtual Network | ✅ | ❌ | Standard VNet creation |
| Subnets | ✅ | ❌ | Basic subnet management |
| Service Endpoints | ✅ | ❌ | Module handles configuration |
| Network Security Groups | ❌ | ✅ | Custom security rules needed |
| NSG Rules | ❌ | ✅ | Organization-specific requirements |
| NSG Associations | ❌ | ✅ | Custom association logic |

## Migration Benefits

1. **Reduced Lines of Code**: ~40% reduction in networking code
2. **Improved Maintainability**: Less custom resource management
3. **Enhanced Reliability**: Proven module with community testing
4. **Better Documentation**: Self-documenting through module interface
5. **Future-Proofing**: Automatic updates with new Azure features

## Best Practices

1. **Pin Module Versions**: Use `~> 4.0` for stability
2. **Review Module Updates**: Test new versions in non-production first
3. **Custom Resources**: Only use direct resources when module limitations exist
4. **Documentation**: Keep this README updated with changes
5. **Testing**: Validate both module and custom resource configurations

## Dependencies

- `Azure/vnet/azurerm` module version `~> 4.0`
- AzureRM provider version `~> 3.0`
- Terraform version `>= 1.0`

## Support

For module-specific issues, refer to:
- [Azure VNet Module Documentation](https://registry.terraform.io/modules/Azure/vnet/azurerm/latest)
- [Azure VNet Module GitHub](https://github.com/Azure/terraform-azurerm-vnet)

For custom resource configurations, refer to:
- [AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest)