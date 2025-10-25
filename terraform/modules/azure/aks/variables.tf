# AKS Module Variables
# Following the same pattern as other modules for consistency

# Basic Configuration
variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "rg_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where AKS cluster will be deployed (from spoke VNet)"
  type        = string
}

# Environment Configuration (for naming consistency)
variable "location_code" {
  description = "Location code for resource naming"
  type        = string
}

variable "client" {
  description = "Client name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
}

# Network Configuration
variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy for AKS (azure, calico, or null)"
  type        = string
  default     = "azure"
}

# Kubernetes Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "1.33"
}

# Default Node Pool Configuration (matching production requirements)
variable "default_node_pool" {
  description = "Configuration for the default node pool"
  type = object({
    name                   = string
    vm_size                = string
    availability_zones     = list(string)
    enable_auto_scaling    = bool
    max_count              = number
    min_count              = number
    node_count             = number
    os_disk_size_gb        = number
    os_disk_type           = string
    ultra_ssd_enabled      = bool
    node_labels            = map(string)
    node_taints            = list(string)
    enable_host_encryption = bool
    max_pods               = number
  })
  default = {
    name                   = "system"
    vm_size                = "Standard_B4ms"
    availability_zones     = [] # No AZ for CS environment - simpler deployment
    enable_auto_scaling    = true
    max_count              = 5
    min_count              = 2
    node_count             = 2
    os_disk_size_gb        = 128
    os_disk_type           = "Managed"
    ultra_ssd_enabled      = false
    node_labels            = {}
    node_taints            = []
    enable_host_encryption = false
    max_pods               = 110
  }
}

# Additional Node Pools (for workload separation)
variable "additional_node_pools" {
  description = "Additional node pools for specific workloads"
  type = map(object({
    vm_size                = string
    availability_zones     = list(string)
    enable_auto_scaling    = bool
    max_count              = number
    min_count              = number
    node_count             = number
    os_disk_size_gb        = number
    os_disk_type           = string
    node_labels            = map(string)
    node_taints            = list(string)
    enable_host_encryption = bool
    max_pods               = number
  }))
  default = {}
}

# Authentication Configuration
variable "admin_group_object_ids" {
  description = "Azure AD group object IDs for AKS administrators"
  type        = list(string)
  default     = []
}

variable "azure_rbac_enabled" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

variable "local_account_disabled" {
  description = "Disable local accounts (use Azure AD only)"
  type        = bool
  default     = true
}

# Security Configuration
variable "private_cluster_enabled" {
  description = "Enable private cluster (API server not publicly accessible)"
  type        = bool
  default     = false
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Enable public FQDN for private cluster"
  type        = bool
  default     = false
}

# Add-ons Configuration
variable "enable_log_analytics_workspace" {
  description = "Enable Log Analytics workspace and OMS agent"
  type        = bool
  default     = true
}

variable "enable_microsoft_defender" {
  description = "Enable Microsoft Defender for Containers"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy add-on"
  type        = bool
  default     = true
}

variable "enable_application_gateway" {
  description = "Enable Application Gateway Ingress Controller"
  type        = bool
  default     = false
}

variable "application_gateway_subnet_cidr" {
  description = "CIDR for Application Gateway subnet (if enabled)"
  type        = string
  default     = null
}

# Key Vault Secrets Provider
variable "enable_secret_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = true
}

variable "secret_rotation_interval" {
  description = "Secret rotation interval"
  type        = string
  default     = "2m"
}

# External Container Registry Configuration
variable "external_container_registry" {
  description = "Configuration for connecting to existing container registry"
  type = object({
    name           = string
    resource_group = string
  })
  default = null
}

# Storage Configuration for Logi Symphony
variable "storage_classes" {
  description = "Storage classes for Logi Symphony workloads"
  type = map(object({
    provisioner            = string
    reclaim_policy         = string
    volume_binding_mode    = string
    allow_volume_expansion = bool
    parameters             = map(string)
  }))
  default = {
    "logi-fast-ssd" = {
      provisioner            = "disk.csi.azure.com"
      reclaim_policy         = "Delete"
      volume_binding_mode    = "WaitForFirstConsumer"
      allow_volume_expansion = true
      parameters = {
        "skuName"     = "Premium_LRS"
        "kind"        = "Managed"
        "cachingmode" = "ReadOnly"
      }
    }
    "logi-standard" = {
      provisioner            = "disk.csi.azure.com"
      reclaim_policy         = "Delete"
      volume_binding_mode    = "WaitForFirstConsumer"
      allow_volume_expansion = true
      parameters = {
        "skuName" = "StandardSSD_LRS"
        "kind"    = "Managed"
      }
    }
  }
}

# Logi Symphony Namespace
variable "create_logi_namespace" {
  description = "Create dedicated namespace for Logi Symphony"
  type        = bool
  default     = true
}

variable "logi_namespace_name" {
  description = "Name for Logi Symphony namespace"
  type        = string
  default     = "logi-symphony"
}

# Additional Network Security Rules
variable "create_additional_nsg_rules" {
  description = "Create additional NSG rules for AKS subnet"
  type        = bool
  default     = false
}

variable "additional_nsg_rules" {
  description = "Additional NSG rules for Logi Symphony ingress"
  type = map(object({
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_ranges    = list(string)
    source_address_prefixes    = list(string)
    destination_address_prefix = string
  }))
  default = {}
}

# Route Table Configuration
variable "create_aks_route_table" {
  description = "Create route table for AKS subnet to ensure proper connectivity"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}