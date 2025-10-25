# CS Environment Configuration for EM NextGen Infrastructure
# Hub-Spoke Architecture using EM Module Pattern
# Compatible with official Azure VNet modules

# Basic Environment Configuration
location_code = "US1"
client        = "BOFA"
environment   = "CS"
location      = "East US"

# ========================================
# MODULE ENABLE/DISABLE FLAGS
# ========================================
enable_hub     = true  # Create dedicated hub
enable_sftp    = true  # Enable SFTP
enable_web_vms = true  # Enable Web VMs
enable_app_vms = true  # Enable App VMs
enable_db_vms  = true  # Enable DB VMs
enable_ado_vms = true  # Enable ADO agents
enable_aks     = false # AKS not deployed yet

# SFTP Optional Features (disabled by default)
# enable_sftp_firewall = true    # Enable Azure Firewall (~$500/month) - Set to true if needed
# enable_sftp_automation = true  # Enable Automation Account for file sync - Set to true if needed

# Hub Network Configuration
# Using 10.223.40.0/24 for hub services and gateway connectivity
# Hub subnets are defined in main.tf locals block:
# - GatewaySubnet: 10.223.40.0/26
# - AzureBastionSubnet: 10.223.40.64/26
# - Shared Services: 10.223.40.128/26
# - Management: 10.223.40.192/26
hub_vnet_address_space = "10.223.40.0/24"

# Spoke Network Configuration
# Using 10.223.48.0/21 for application workloads and data services
# Total range: 10.223.48.0 - 10.223.55.255 (2048 IPs, supports 8 /24 subnets)
# Current spoke subnets (all /24 for 256 IPs each):
# - Web Subnet: 10.223.48.0/24 (256 IPs)
# - App Subnet: 10.223.49.0/24 (256 IPs)
# - Database Subnet: 10.223.50.0/24 (256 IPs)
# - DevOps Subnet: 10.223.51.0/24 (256 IPs)
# - Logi Subnet: 10.223.52.0/24 (256 IPs) - AKS will use this subnet
# - Application Gateway Subnet: 10.223.53.0/24 (256 IPs) - Dedicated for App Gateway
# - Available: 10.223.54.0/24, 10.223.55.0/24 (future expansion)
spoke_vnet_address_space = "10.223.48.0/21"

# Spoke subnets use defaults from variables.tf (CS ranges)
# Explicitly defining here for clarity and to match deployed infrastructure
spoke_subnets = {
  "WEB-SUBNET" = {
    address_prefix    = "10.223.48.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Web"]
  }
  "APP-SUBNET" = {
    address_prefix    = "10.223.49.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  "DB-SUBNET" = {
    address_prefix    = "10.223.50.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  "ADO-SUBNET" = {
    address_prefix    = "10.223.51.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
  }
  "LOGI-SUBNET" = {
    address_prefix    = "10.223.52.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
  }
  "AG-SUBNET" = {
    address_prefix    = "10.223.53.0/24"
    service_endpoints = []
  }
  "SFTP-SUBNET" = {
    address_prefix    = "10.223.54.0/24"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }
}

# Logi AKS Configuration (matching production US1-BOFA-P-LOGI setup)
kubernetes_version          = "1.33"
enable_logi_dedicated_nodes = true
logi_node_taints            = ["workload=analytics:NoSchedule"]

# AKS Security Configuration
aks_disable_local_accounts              = true
aks_private_cluster_enabled             = false # Set to true for production-like security
aks_private_cluster_public_fqdn_enabled = false

# AKS Add-ons
enable_aks_log_analytics      = false
enable_aks_microsoft_defender = false
enable_aks_azure_policy       = true

# External Container Registry Configuration (connect to existing registry)
external_logi_container_registry = {
  name           = "your-existing-registry-name"
  resource_group = "your-existing-registry-rg"
}

# Logi Symphony Configuration
logi_namespace_name = "logi-symphony"

# Azure DevOps Configuration
ado_organization_url = "https://dev.azure.com/insight-certent/"
ado_deployment_pool  = "EM-BOFA-CS"

# DNS Configuration for Domain Resolution
# Domain controllers and Google DNS as fallback
dns_servers = ["10.223.26.68", "10.223.26.69", "8.8.8.8"]

# Azure AD Domain Services VNet Configuration (for domain join)
aadds_vnet_name           = "US1-BOFA-P-DS-VNET"
aadds_vnet_resource_group = "US1-BOFA-P-DS"

# Azure AD Configuration for VPN Gateway
# Tenant ID is automatically detected from current Azure authentication context

# Resource Tags
tags = {
  Environment  = "CS"
  Client       = "BOFA"
  Region       = "US1"
  Project      = "EM-NextGen"
  ManagedBy    = "Terraform"
  Purpose      = "Customer-Service"
  Owner        = "CloudOps-Team"
  Architecture = "Hub-Spoke"
}