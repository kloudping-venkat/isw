# Azure Kubernetes Service using official Azure module
# Following the same pattern as networking module for consistency

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Local variables for naming consistency
locals {
  prefix = "${var.location_code}-${var.client}-${var.environment}"
}

# Azure Kubernetes Service using official module
module "aks" {
  source  = "Azure/aks/azurerm"
  version = "~> 8.0"

  # Basic Configuration
  resource_group_name = var.rg_name
  location            = var.location
  cluster_name        = var.cluster_name
  prefix              = lower("${var.location_code}${var.client}${var.environment}logi")

  # Network Configuration - Use existing subnet (similar to production setup)
  vnet_subnet_id = var.subnet_id
  network_plugin = var.network_plugin
  network_policy = var.network_policy

  # Node Pool Configuration (using individual parameters)
  agents_count              = var.default_node_pool.node_count
  agents_max_count          = var.default_node_pool.max_count
  agents_min_count          = var.default_node_pool.min_count
  agents_pool_name          = var.default_node_pool.name
  agents_size               = var.default_node_pool.vm_size
  agents_availability_zones = var.default_node_pool.availability_zones
  enable_auto_scaling       = var.default_node_pool.enable_auto_scaling
  os_disk_size_gb           = var.default_node_pool.os_disk_size_gb
  agents_labels             = var.default_node_pool.node_labels
  agents_taints             = var.default_node_pool.node_taints
  agents_max_pods           = var.default_node_pool.max_pods

  # Enable public IPs for outbound connectivity
  enable_node_public_ip = true

  # Kubernetes Version
  kubernetes_version = var.kubernetes_version

  # Authentication Configuration
  role_based_access_control_enabled = true
  rbac_aad_managed                  = true
  rbac_aad_tenant_id                = data.azurerm_client_config.current.tenant_id
  rbac_aad_admin_group_object_ids   = var.admin_group_object_ids
  rbac_aad_azure_rbac_enabled       = var.azure_rbac_enabled

  # Identity Configuration (System Assigned Managed Identity)
  identity_type = "SystemAssigned"

  # Add-ons Configuration (matching production Logi requirements)
  log_analytics_workspace_enabled = false
  microsoft_defender_enabled      = false
  azure_policy_enabled            = var.enable_azure_policy

  # Security Configuration
  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled

  # Additional Security
  local_account_disabled = var.local_account_disabled

  # Key Vault Secrets Provider (for Logi credentials)
  secret_rotation_enabled  = var.enable_secret_rotation
  secret_rotation_interval = var.secret_rotation_interval

  # Tags
  tags = merge(var.tags, {
    Purpose = "Logi Analytics Platform"
    Module  = "aks"
  })
}

# Additional Node Pools (if specified)
resource "azurerm_kubernetes_cluster_node_pool" "additional_node_pools" {
  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = module.aks.aks_id
  vm_size               = each.value.vm_size
  zones                 = each.value.availability_zones

  # Scaling Configuration
  enable_auto_scaling = each.value.enable_auto_scaling
  max_count           = each.value.max_count
  min_count           = each.value.min_count
  node_count          = each.value.node_count

  # Storage Configuration
  os_disk_size_gb = each.value.os_disk_size_gb
  os_disk_type    = each.value.os_disk_type

  # Network Configuration
  vnet_subnet_id        = var.subnet_id
  enable_node_public_ip = true # Enable public IPs for outbound connectivity
  max_pods              = each.value.max_pods

  # Node Configuration
  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  # Kubernetes Version
  orchestrator_version = var.kubernetes_version

  tags = merge(var.tags, {
    Purpose  = "Logi Analytics Platform"
    Module   = "aks"
    NodePool = each.key
  })
}

# Role assignment for external container registry access
resource "azurerm_role_assignment" "aks_external_acr_pull" {
  count = var.external_container_registry != null ? 1 : 0

  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.external_container_registry.resource_group}/providers/Microsoft.ContainerRegistry/registries/${var.external_container_registry.name}"
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity[0].object_id
}

# Storage Classes for Logi Symphony (PostgreSQL and persistent volumes)
resource "kubernetes_storage_class" "logi_storage_classes" {
  for_each = var.storage_classes

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "purpose"                      = "logi-symphony"
    }
  }

  storage_provisioner    = each.value.provisioner
  reclaim_policy         = each.value.reclaim_policy
  volume_binding_mode    = each.value.volume_binding_mode
  allow_volume_expansion = each.value.allow_volume_expansion

  parameters = each.value.parameters

  depends_on = [module.aks]
}

# Namespace for Logi Symphony
resource "kubernetes_namespace" "logi_namespace" {
  count = var.create_logi_namespace ? 1 : 0

  metadata {
    name = var.logi_namespace_name
    labels = {
      "app.kubernetes.io/name"       = "logi-symphony"
      "app.kubernetes.io/managed-by" = "terraform"
      "purpose"                      = "analytics-platform"
    }
  }

  depends_on = [module.aks]
}

# Network Security Group for AKS subnet (if needed for additional rules)
resource "azurerm_network_security_group" "aks_nsg" {
  count = var.create_additional_nsg_rules ? 1 : 0

  name                = "${var.cluster_name}-additional-nsg"
  location            = var.location
  resource_group_name = var.rg_name

  tags = merge(var.tags, {
    Purpose = "AKS Additional Security Rules"
    Module  = "aks"
  })
}

# Additional NSG Rules for Logi Symphony (if needed)
resource "azurerm_network_security_rule" "logi_ingress_rules" {
  for_each = var.create_additional_nsg_rules ? var.additional_nsg_rules : {}

  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_ranges     = each.value.destination_port_ranges
  source_address_prefixes     = each.value.source_address_prefixes
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.aks_nsg[0].name
}

# Route Table for AKS subnet (to ensure proper routing to other subnets)
resource "azurerm_route_table" "aks_route_table" {
  count = var.create_aks_route_table ? 1 : 0

  name                = "${var.cluster_name}-rt"
  location            = var.location
  resource_group_name = var.rg_name

  # Route to hub VNet for VPN connectivity
  route {
    name           = "ToHubVNet"
    address_prefix = "10.223.40.0/24" # Hub VNet CIDR
    next_hop_type  = "VnetLocal"
  }

  # Route to other spoke subnets
  route {
    name           = "ToSpokeSubnets"
    address_prefix = "10.223.48.0/21" # Spoke VNet CIDR
    next_hop_type  = "VnetLocal"
  }

  # Route to VPN clients
  route {
    name           = "ToVPNClients"
    address_prefix = "172.16.0.0/24" # VPN client range
    next_hop_type  = "VirtualNetworkGateway"
  }

  tags = merge(var.tags, {
    Purpose = "AKS Routing Configuration"
    Module  = "aks"
  })
}