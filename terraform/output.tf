# HUB Resource Group Outputs
output "hub_resource_group_name" {
  description = "The name of the HUB resource group"
  value       = azurerm_resource_group.environment_rgs["HUB"].name
}

output "hub_resource_group_location" {
  description = "The location of the HUB resource group"
  value       = var.location
}

# SPOKE Resource Group Outputs
output "spoke_resource_group_name" {
  description = "The name of the SPOKE resource group"
  value       = azurerm_resource_group.environment_rgs["SPOKE"].name
}

output "spoke_resource_group_location" {
  description = "The location of the SPOKE resource group"
  value       = var.location
}

# Key Vault Outputs
output "web_key_vault_name" {
  description = "Name of the WEB Key Vault"
  value       = var.enable_web_vms ? module.web_resources[0].key_vault_name : null
}

output "app_key_vault_name" {
  description = "Name of the APP Key Vault"
  value       = var.enable_app_vms ? module.app_resources[0].key_vault_name : null
}

# Windows Server Outputs
output "web_servers" {
  description = "Information about deployed WEB servers"
  value       = var.enable_web_vms ? module.web_resources[0].virtual_machines : {}
}

output "app_servers" {
  description = "Information about deployed APP servers"
  value       = var.enable_app_vms ? module.app_resources[0].virtual_machines : {}
}

# VPN Gateway Outputs
output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = var.enable_hub ? module.hub_infrastructure[0].vpn_gateway_name : null
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = var.enable_hub ? module.hub_infrastructure[0].vpn_gateway_public_ip : null
}

output "vpn_client_config_secret" {
  description = "Key Vault secret name containing VPN client configuration"
  value       = var.enable_hub ? module.hub_infrastructure[0].vpn_client_config_secret : null
}

output "vpn_client_address_space" {
  description = "VPN client address space"
  value       = var.enable_hub ? module.hub_infrastructure[0].vpn_client_address_space : null
}

# Storage Account Outputs - Commented out as storage module is not declared
# output "storage_account_name" {
#   description = "The name of the created storage account"
#   value       = module.storage.storage_account_name
# }

# output "storage_account_id" {
#   description = "The ID of the storage account"
#   value       = module.storage.storage_account_id
# }

# output "primary_blob_endpoint" {
#   description = "The endpoint URL for blob storage"
#   value       = module.storage.primary_blob_endpoint
# }

# output "container_name" {
#   description = "The name of the created container"
#   value       = module.storage.container_name
# }

# TEMPORARY OUTPUTS FOR TROUBLESHOOTING ADO VM PASSWORDS - REMOVE IN PRODUCTION
output "ado_vm_passwords" {
  description = "TEMPORARY: ADO VM admin passwords for troubleshooting (REMOVE IN PRODUCTION)"
  value       = var.enable_ado_vms ? module.ado_resources[0].vm_admin_passwords : {}
  sensitive   = true
}

# Oracle Database Outputs
output "oracle_database_info" {
  description = "Oracle Database connection and configuration information"
  value = var.enable_db_vms ? (
    var.enable_db_vm_02 ? {
      vm_name            = module.db_resources_02[0].vm_name
      vm_private_ip      = module.db_resources_02[0].vm_private_ip
      connection_details = module.db_resources_02[0].oracle_connection_details
      key_vault_secrets  = module.db_resources_02[0].key_vault_secrets
    } : var.enable_db_vm_01 ? {
      vm_name            = module.db_resources_01[0].vm_name
      vm_private_ip      = module.db_resources_01[0].vm_private_ip
      connection_details = module.db_resources_01[0].oracle_connection_details
      key_vault_secrets  = module.db_resources_01[0].key_vault_secrets
    } : null
  ) : null
  sensitive = true
}

output "db_key_vault_name" {
  description = "Name of the DB Key Vault"
  value       = var.enable_db_vms ? module.db_key_vault[0].key_vault_name : null
}

# Application Gateway Outputs
output "web_application_gateway_name" {
  description = "Name of the WEB Application Gateway"
  value       = var.enable_web_vms ? module.web_resources[0].application_gateway_name : null
}

output "web_application_gateway_public_ip" {
  description = "Public IP address of the WEB Application Gateway"
  value       = var.enable_web_vms ? module.web_resources[0].application_gateway_public_ip : null
}

output "web_application_gateway_id" {
  description = "ID of the WEB Application Gateway"
  value       = var.enable_web_vms ? module.web_resources[0].application_gateway_id : null
}

output "web_application_gateway_identity_principal_id" {
  description = "Principal ID of the WEB Application Gateway managed identity"
  value       = var.enable_web_vms ? module.web_resources[0].application_gateway_identity_principal_id : null
}

# VM Login Information
output "vm_login_info" {
  description = "VM login information for troubleshooting"
  sensitive   = true
  value = var.enable_web_vms || var.enable_app_vms || var.enable_ado_vms || var.enable_db_vms ? {
    web_vm = var.enable_web_vms ? {
      vm_name        = keys(module.web_resources[0].virtual_machines)[0]
      computer_name  = values(module.web_resources[0].virtual_machines)[0].vm_computer_name
      admin_username = values(module.web_resources[0].virtual_machines)[0].vm_admin_username
      private_ip     = values(module.web_resources[0].virtual_machines)[0].vm_private_ip
    } : null
    app_vm = var.enable_app_vms ? {
      vm_name        = keys(module.app_resources[0].virtual_machines)[0]
      computer_name  = values(module.app_resources[0].virtual_machines)[0].vm_computer_name
      admin_username = values(module.app_resources[0].virtual_machines)[0].vm_admin_username
      private_ip     = values(module.app_resources[0].virtual_machines)[0].vm_private_ip
    } : null
    ado_vm = var.enable_ado_vms ? {
      vm_name        = keys(module.ado_resources[0].virtual_machines)[0]
      computer_name  = values(module.ado_resources[0].virtual_machines)[0].vm_computer_name
      admin_username = values(module.ado_resources[0].virtual_machines)[0].vm_admin_username
      private_ip     = values(module.ado_resources[0].virtual_machines)[0].vm_private_ip
    } : null
    db_vm = var.enable_db_vms ? (
      var.enable_db_vm_02 ? {
        vm_name        = module.db_resources_02[0].vm_name
        computer_name  = module.db_resources_02[0].vm_computer_name
        admin_username = module.db_resources_02[0].vm_admin_username
        private_ip     = module.db_resources_02[0].vm_private_ip
      } : var.enable_db_vm_01 ? {
        vm_name        = module.db_resources_01[0].vm_name
        computer_name  = module.db_resources_01[0].vm_computer_name
        admin_username = module.db_resources_01[0].vm_admin_username
        private_ip     = module.db_resources_01[0].vm_private_ip
      } : null
    ) : null
  } : null
}

# Logi AKS Cluster Outputs - TEMPORARILY DISABLED
# output "logi_aks_cluster_name" {
#   description = "Name of the Logi AKS cluster"
#   value       = module.logi_aks.aks_cluster_name
# }
#
# output "logi_aks_cluster_id" {
#   description = "ID of the Logi AKS cluster"
#   value       = module.logi_aks.aks_cluster_id
# }
#
# output "logi_aks_cluster_fqdn" {
#   description = "FQDN of the Logi AKS cluster"
#   value       = module.logi_aks.aks_cluster_fqdn
#   sensitive   = true
# }
#
# output "logi_external_container_registry" {
#   description = "External Container Registry configuration"
#   value = {
#     configured     = module.logi_aks.external_container_registry_configured
#     registry_info  = module.logi_aks.container_registry_access
#   }
# }
#
# output "logi_namespace" {
#   description = "Logi Symphony Kubernetes namespace"
#   value       = module.logi_aks.logi_namespace_name
# }
#
# output "logi_helm_deployment_info" {
#   description = "Information for deploying Logi Symphony via Helm"
#   value       = module.logi_aks.helm_deployment_info
# }
#
# output "logi_ingress_configuration" {
#   description = "Ingress configuration for Logi Symphony"
#   value       = module.logi_aks.ingress_configuration
# }
#
# # AKS Connection Commands
# output "aks_connection_commands" {
#   description = "Commands to connect to the AKS cluster"
#   value = {
#     get_credentials = "az aks get-credentials --resource-group ${azurerm_resource_group.environment_rgs["LOGI"].name} --name ${module.logi_aks.aks_cluster_name}"
#     kubectl_config  = "export KUBECONFIG=~/.kube/config"
#     test_connection = "kubectl get nodes"
#   }
# }

# ========================================
# SFTP OUTPUTS
# ========================================
output "sftp_storage_account_name" {
  description = "SFTP Storage Account Name"
  value       = var.enable_sftp ? module.sftp[0].storage_account_name : null
}

output "sftp_primary_blob_endpoint" {
  description = "SFTP Primary Blob Endpoint"
  value       = var.enable_sftp ? module.sftp[0].storage_account_primary_blob_endpoint : null
}

output "sftp_nat_gateway_public_ip" {
  description = "SFTP NAT Gateway Public IP (for whitelisting)"
  value       = var.enable_sftp ? module.sftp[0].nat_gateway_public_ip : null
}

output "sftp_private_endpoint_ip" {
  description = "SFTP Private Endpoint IP Address"
  value       = var.enable_sftp ? module.sftp[0].private_endpoint_ip_address : null
}

output "sftp_connection_string" {
  description = "SFTP Connection String Format"
  value       = var.enable_sftp ? "sftp <username>.${module.sftp[0].storage_account_name}@${module.sftp[0].storage_account_name}.blob.core.windows.net" : null
}
