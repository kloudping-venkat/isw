# BAML Production Environment Configuration
# Hub-Spoke Architecture using EM Module Pattern

# Basic Environment Configuration
location_code = "US1"
client        = "BAML"
environment   = "PROD"
location      = "East US"

# Hub Network Configuration
hub_vnet_address_space = "10.224.16.0/24"

# Spoke Network Configuration
spoke_vnet_address_space = "10.224.24.0/21"

# Logi AKS Configuration
kubernetes_version          = "1.33"
enable_logi_dedicated_nodes = true
logi_node_taints            = ["workload=analytics:NoSchedule"]

# AKS Security Configuration
aks_disable_local_accounts              = true
aks_private_cluster_enabled             = true
aks_private_cluster_public_fqdn_enabled = false

# AKS Add-ons
enable_aks_log_analytics      = true
enable_aks_microsoft_defender = true
enable_aks_azure_policy       = true

# Azure DevOps Configuration
ado_organization_url = "https://dev.azure.com/insight-certent/"
ado_deployment_pool  = "EM-BAML-PROD"

# DNS Configuration
dns_servers = ["8.8.8.8", "8.8.4.4"]

# Resource Tags
tags = {
  Environment  = "PROD"
  Client       = "BAML"
  Region       = "US1"
  Project      = "EM-NextGen"
  ManagedBy    = "Terraform"
  Purpose      = "Production"
  Owner        = "CloudOps-Team"
  Architecture = "Hub-Spoke"
}
