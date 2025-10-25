# AKS Module Outputs
# Following the same pattern as other modules

# AKS Cluster Outputs
output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.aks_id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.host
}

output "aks_cluster_private_fqdn" {
  description = "Private FQDN of the AKS cluster"
  value       = var.private_cluster_enabled ? "Private cluster enabled - use kubectl from within VNet" : null
}

output "aks_cluster_portal_fqdn" {
  description = "Portal FQDN of the AKS cluster"
  value       = "Use Azure Portal to access cluster dashboard"
}

output "aks_cluster_kubelet_identity" {
  description = "Kubelet identity information"
  value       = module.aks.kubelet_identity
}

output "aks_cluster_identity" {
  description = "AKS cluster identity information"
  value       = module.aks.cluster_identity
}

# Node Pool Information
output "aks_system_node_pool" {
  description = "System node pool information"
  value = {
    name       = var.default_node_pool.name
    vm_size    = var.default_node_pool.vm_size
    node_count = var.default_node_pool.node_count
  }
}

output "aks_additional_node_pools" {
  description = "Additional node pools information"
  value = {
    for name, pool in azurerm_kubernetes_cluster_node_pool.additional_node_pools : name => {
      id         = pool.id
      name       = pool.name
      vm_size    = pool.vm_size
      node_count = pool.node_count
    }
  }
}

# External Container Registry Information
output "external_container_registry_configured" {
  description = "Whether external container registry is configured"
  value       = var.external_container_registry != null
}

output "container_registry_access" {
  description = "Container registry access information"
  value = var.external_container_registry != null ? {
    registry_name  = var.external_container_registry.name
    resource_group = var.external_container_registry.resource_group
    access_granted = true
  } : null
}

# Logi Symphony Specific Outputs
output "logi_namespace_name" {
  description = "Name of the Logi Symphony namespace"
  value       = var.create_logi_namespace ? kubernetes_namespace.logi_namespace[0].metadata[0].name : null
}

output "storage_classes" {
  description = "Created storage classes for Logi Symphony"
  value = {
    for name, sc in kubernetes_storage_class.logi_storage_classes : name => {
      name        = sc.metadata[0].name
      provisioner = sc.storage_provisioner
    }
  }
}

# Connection Information for Applications
output "cluster_connection_info" {
  description = "Information needed to connect to the AKS cluster"
  value = {
    cluster_name    = module.aks.aks_name
    cluster_fqdn    = module.aks.host
    resource_group  = var.rg_name
    subscription_id = data.azurerm_client_config.current.subscription_id
    tenant_id       = data.azurerm_client_config.current.tenant_id
  }
  sensitive = true
}

# Ingress Configuration
output "ingress_configuration" {
  description = "Ingress configuration information for Logi Symphony"
  value = {
    application_gateway_enabled = var.enable_application_gateway
    nginx_ingress_class         = "nginx"
    recommended_annotations = {
      "kubernetes.io/tls-acme"                             = "true"
      "nginx.ingress.kubernetes.io/proxy-http-version"     = "1.1"
      "nginx.ingress.kubernetes.io/ssl-redirect"           = "false"
      "nginx.ingress.kubernetes.io/affinity"               = "cookie"
      "nginx.ingress.kubernetes.io/session-cookie-name"    = "symphonyroute"
      "nginx.ingress.kubernetes.io/session-cookie-expires" = "172800"
      "nginx.ingress.kubernetes.io/session-cookie-max-age" = "172800"
      "nginx.ingress.kubernetes.io/session-cookie-path"    = "/"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout"  = "86400"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"     = "86400"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"     = "86400"
      "nginx.ingress.kubernetes.io/proxy-body-size"        = "500m"
    }
  }
}

# Helm Deployment Information
output "helm_deployment_info" {
  description = "Information for deploying Logi Symphony via Helm"
  value = {
    namespace = var.create_logi_namespace ? kubernetes_namespace.logi_namespace[0].metadata[0].name : "default"
    storage_classes = {
      fast_ssd = "logi-fast-ssd"
      standard = "logi-standard"
    }
    recommended_values = {
      "ingress.enabled"                        = true
      "ingress.spec.ingressClassName"          = "nginx"
      "postgresql.enabled"                     = false # Use external PostgreSQL as per production
      "rabbitmq.enabled"                       = true
      "global.logi.symphony.managed.enabled"   = true
      "global.logi.symphony.discovery.enabled" = true
    }
  }
}

# Monitoring and Logging
output "monitoring_configuration" {
  description = "Monitoring and logging configuration"
  value = {
    log_analytics_enabled      = var.enable_log_analytics_workspace
    microsoft_defender_enabled = var.enable_microsoft_defender
    azure_policy_enabled       = var.enable_azure_policy
    oms_agent_enabled          = var.enable_log_analytics_workspace
  }
}

# Network Security
output "network_security_info" {
  description = "Network security configuration information"
  value = {
    network_plugin          = var.network_plugin
    network_policy          = var.network_policy
    private_cluster_enabled = var.private_cluster_enabled
    additional_nsg_created  = var.create_additional_nsg_rules
    route_table_created     = var.create_aks_route_table
    subnet_id               = var.subnet_id
  }
}

# Route Table Output
output "aks_route_table_id" {
  description = "ID of the AKS route table (if created)"
  value       = var.create_aks_route_table ? azurerm_route_table.aks_route_table[0].id : null
}