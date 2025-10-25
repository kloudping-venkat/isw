# EM NextGen AKS Module

## Overview

This AKS module implements a hybrid approach combining the official **Azure AKS Terraform module** with custom direct resources to achieve optimal balance between standardization and flexibility for Logi Symphony analytics platform.

## Architecture Approach

### 🎯 Hybrid Strategy

**Azure Module Components** (`Azure/aks/azurerm`):
- AKS cluster creation and management
- Node pool provisioning and auto-scaling
- Azure AD integration and RBAC configuration
- Add-ons management (Log Analytics, Microsoft Defender, Azure Policy)
- Network plugin and policy configuration

**Direct Terraform Resources**:
- Azure Container Registry (ACR) for Logi Symphony images
- Kubernetes storage classes optimized for analytics workloads
- Custom network security groups for AKS-specific rules
- Route tables for VPN and cross-subnet connectivity
- Kubernetes namespaces and RBAC configurations

## Benefits

### ✅ Advantages of Using Azure AKS Module

1. **Standardization & Best Practices**
   - Follows Microsoft's recommended AKS patterns
   - Regularly updated with latest Kubernetes features
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
   - Simplified AKS cluster creation
   - Built-in node pool management
   - Reduced boilerplate code

### 🔧 When Direct Resources Are Needed

**Logi Symphony-Specific Requirements**:
- Custom storage classes for analytics workloads
- Container registry with specific access policies
- Network security rules for Logi ingress traffic
- Route tables for VPN and database connectivity

**Advanced Kubernetes Features**:
- Custom namespaces with specific RBAC
- Storage provisioners for persistent volumes
- Network policies for micro-segmentation

## Implementation Details

### Module Usage
```hcl
module "aks" {
  source  = "Azure/aks/azurerm"
  version = "~> 8.0"

  resource_group_name = var.rg_name
  location            = var.location
  cluster_name        = var.cluster_name
  
  # Network Configuration
  vnet_subnet_id = var.subnet_id
  network_plugin = "azure"
  network_policy = "azure"

  # Node Pool Configuration
  default_node_pool = {
    name                = "system"
    vm_size            = "Standard_B4ms"
    availability_zones = ["1", "2", "3"]
    enable_auto_scaling = true
    max_count          = 5
    min_count          = 2
  }

  # Authentication
  azure_active_directory_role_based_access_control = {
    managed                = true
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  tags = var.tags
}
```

### Custom Logi Symphony Resources
```hcl
# Container Registry for Logi Symphony images
resource "azurerm_container_registry" "acr" {
  count = var.create_container_registry ? 1 : 0

  name                = var.container_registry_name
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = var.container_registry_sku
}

# Storage Classes for Logi workloads
resource "kubernetes_storage_class" "logi_storage_classes" {
  for_each = var.storage_classes

  metadata {
    name = each.key
  }
  storage_provisioner = each.value.provisioner
  parameters         = each.value.parameters
}
```

## Resource Coverage

| Resource Type | Azure Module | Direct Resource | Reason |
|---------------|--------------|-----------------|---------|
| AKS Cluster | ✅ | ❌ | Standard cluster creation |
| Node Pools | ✅ | ❌ | Built-in auto-scaling management |
| Azure AD Integration | ✅ | ❌ | Module handles RBAC configuration |
| Add-ons (Log Analytics, etc.) | ✅ | ❌ | Module manages add-on lifecycle |
| Container Registry | ❌ | ✅ | Logi-specific access policies |
| Storage Classes | ❌ | ✅ | Analytics workload optimization |
| Network Security Groups | ❌ | ✅ | Custom VPN and subnet rules |
| Route Tables | ❌ | ✅ | Cross-subnet connectivity |
| Kubernetes Namespaces | ❌ | ✅ | Logi Symphony isolation |

## Logi Symphony Integration

### Network Architecture
```
Hub VNet (10.223.40.0/24)
├── VPN Gateway (172.16.0.0/24 for clients)
└── Peered to Spoke VNet

Spoke VNet (10.223.44.0/22)
├── LOGI-SUBNET: 10.223.45.128/25  ← AKS cluster resides here
├── APP-SUBNET:  10.223.44.128/25  → Can connect to LOGI
├── WEB-SUBNET:  10.223.44.0/25    → Can connect to LOGI
└── DB-SUBNET:   10.223.45.0/25    → Accepts connections from LOGI
```

### Connectivity Matrix
| From/To | VPN Clients | WEB Subnet | APP Subnet | DB Subnet |
|---------|-------------|------------|------------|-----------|
| **LOGI AKS** | ✅ HTTP/HTTPS/9090 | ✅ HTTP/HTTPS/9090 | ✅ HTTP/HTTPS/9090 | ✅ DB Ports |

### Storage Classes Created
- **logi-fast-ssd**: Premium SSD for high-performance analytics
- **logi-standard**: Standard SSD for general workloads

## Migration Benefits

1. **Reduced Lines of Code**: ~50% reduction in AKS configuration code
2. **Improved Maintainability**: Less custom cluster management
3. **Enhanced Reliability**: Proven module with community testing
4. **Better Documentation**: Self-documenting through module interface
5. **Future-Proofing**: Automatic updates with new Kubernetes features

## Usage Example

### Basic Configuration
```hcl
module "logi_aks" {
  source = "./modules/em/aks"

  cluster_name = "US1-BOFA-CS-LOGI-AKS"
  rg_name      = "US1-BOFA-CS-LOGI"
  location     = "East US"
  subnet_id    = module.spoke_vnet.subnet_ids["US1-BOFA-CS-SPOKE-LOGI-SUBNET"]

  location_code = "US1"
  client        = "BOFA"
  environment   = "CS"

  create_container_registry = true
  container_registry_name   = "us1bofacslogiacr"

  tags = var.tags
}
```

### Advanced Configuration with Dedicated Node Pool
```hcl
module "logi_aks" {
  source = "./modules/em/aks"

  # ... basic configuration ...

  additional_node_pools = {
    "logi" = {
      vm_size               = "Standard_D8s_v3"
      availability_zones    = ["1", "2", "3"]
      enable_auto_scaling   = true
      max_count             = 10
      min_count             = 2
      node_count            = 3
      node_labels          = { "workload" = "analytics" }
      node_taints          = ["workload=analytics:NoSchedule"]
    }
  }
}
```

## Post-Deployment

### Connect to AKS Cluster
```bash
# Get AKS credentials
az aks get-credentials --resource-group US1-BOFA-CS-LOGI --name US1-BOFA-CS-LOGI-AKS

# Verify connectivity
kubectl get nodes
kubectl get namespaces
```

### Deploy Logi Symphony
```bash
# Add Logi Helm repository
helm repo add logi https://your-logi-helm-repo-url

# Deploy Logi Symphony to dedicated namespace
helm install logi-symphony logi/symphony \
  --namespace logi-symphony \
  --create-namespace \
  --values production-values.yaml
```

## Best Practices

1. **Pin Module Versions**: Use `~> 8.0` for stability
2. **Review Module Updates**: Test new versions in non-production first
3. **Custom Resources**: Only use direct resources when module limitations exist
4. **Node Pool Strategy**: Use system pool for infrastructure, dedicated pools for workloads
5. **Security**: Enable Azure AD integration and RBAC
6. **Monitoring**: Enable Log Analytics and Microsoft Defender
7. **Testing**: Validate both module and custom resource configurations

## Dependencies

- `Azure/aks/azurerm` module version `~> 8.0`
- `kubernetes` provider version `~> 2.0`
- AzureRM provider version `~> 3.0`
- Terraform version `>= 1.0`

## Support

For module-specific issues, refer to:
- [Azure AKS Module Documentation](https://registry.terraform.io/modules/Azure/aks/azurerm/latest)
- [Azure AKS Module GitHub](https://github.com/Azure/terraform-azurerm-aks)

For Logi Symphony configurations, refer to:
- [Logi Symphony Documentation](https://documentation.logi.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

For custom resource configurations, refer to:
- [AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Kubernetes Provider Documentation](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)