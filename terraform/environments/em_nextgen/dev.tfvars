# EM NextGen Development Environment Configuration
# Hub-Spoke Architecture using EM Module Pattern

# Basic Environment Configuration
location_code = "US1"
client        = "EM_NEXTGEN"
environment   = "DEV"
location      = "East US"

# Hub Network Configuration
hub_vnet_address_space = "10.230.0.0/24"

# Spoke Network Configuration
spoke_vnet_address_space = "10.230.8.0/21"

# Logi AKS Configuration
kubernetes_version          = "1.33"
enable_logi_dedicated_nodes = false

# AKS Security Configuration
aks_disable_local_accounts              = true
aks_private_cluster_enabled             = false
aks_private_cluster_public_fqdn_enabled = false

# AKS Add-ons
enable_aks_log_analytics      = false
enable_aks_microsoft_defender = false
enable_aks_azure_policy       = true

# Azure DevOps Configuration
ado_organization_url = "https://dev.azure.com/insight-certent/"
ado_deployment_pool  = "EM-NEXTGEN-DEV"

# DNS Configuration
dns_servers = ["8.8.8.8", "8.8.4.4"]

# Resource Tags
tags = {
  Environment  = "DEV"
  Client       = "EM_NEXTGEN"
  Region       = "US1"
  Project      = "EM-NextGen"
  ManagedBy    = "Terraform"
  Purpose      = "Development"
  Owner        = "CloudOps-Team"
  Architecture = "Hub-Spoke"
}
