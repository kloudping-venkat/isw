# Application Gateway Module
# Dedicated module for Azure Application Gateway with WAF capabilities

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "${var.appgw_name}-PIP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones

  tags = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # SKU Configuration
  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  # Managed Identity for Key Vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [var.external_identity_id]
  }

  # Gateway IP Configuration
  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = var.subnet_id
  }

  # Frontend Port Configuration
  frontend_port {
    name = "httpPort"
    port = 80
  }

  frontend_port {
    name = "httpsPort"
    port = 443
  }

  # Frontend IP Configuration
  frontend_ip_configuration {
    name                 = "appGatewayFrontendIP"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  # Backend Address Pool
  backend_address_pool {
    name         = "backendPool"
    ip_addresses = var.backend_ip_addresses
  }

  # Backend HTTP Settings (HTTP - for non-SSL backends) - Default fallback (only if no custom settings)
  dynamic "backend_http_settings" {
    for_each = length(var.backend_http_settings_list) == 0 ? [1] : []
    content {
      name                  = "backendHttpSettings"
      cookie_based_affinity = "Disabled"
      port                  = 80
      protocol              = "Http"
      request_timeout       = 30
      probe_name            = "healthProbe"
    }
  }

  # Multiple Backend HTTP Settings (configured via variable)
  dynamic "backend_http_settings" {
    for_each = var.backend_http_settings_list
    content {
      name                                = backend_http_settings.key
      cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
      affinity_cookie_name                = backend_http_settings.value.cookie_based_affinity == "Enabled" ? "ApplicationGatewayAffinity" : null
      port                                = backend_http_settings.value.port
      protocol                            = backend_http_settings.value.protocol
      request_timeout                     = backend_http_settings.value.request_timeout
      probe_name                          = backend_http_settings.value.probe_name
      pick_host_name_from_backend_address = false
    }
  }

  # Health Probe (HTTP) - Default fallback (only if no custom probes)
  dynamic "probe" {
    for_each = length(var.probes_list) == 0 ? [1] : []
    content {
      name                = "healthProbe"
      protocol            = "Http"
      path                = "/"
      host                = var.health_probe_host
      interval            = 30
      timeout             = 30
      unhealthy_threshold = 3
    }
  }

  # Multiple Health Probes (configured via variable)
  dynamic "probe" {
    for_each = var.probes_list
    content {
      name                                      = probe.key
      protocol                                  = probe.value.protocol
      path                                      = probe.value.path
      host                                      = probe.value.host
      interval                                  = probe.value.interval
      timeout                                   = probe.value.timeout
      unhealthy_threshold                       = probe.value.unhealthy_threshold
      pick_host_name_from_backend_http_settings = false
      minimum_servers                           = 0

      match {
        status_code = probe.value.match_status_codes
      }
    }
  }

  # HTTP Listener (only if no custom listeners)
  dynamic "http_listener" {
    for_each = length(var.http_listeners_list) == 0 ? [1] : []
    content {
      name                           = "httpListener"
      frontend_ip_configuration_name = "appGatewayFrontendIP"
      frontend_port_name             = "httpPort"
      protocol                       = "Http"
    }
  }

  # Request Routing Rule (only if no custom routing rules)
  dynamic "request_routing_rule" {
    for_each = length(var.request_routing_rules_list) == 0 ? [1] : []
    content {
      name                       = "routingRule"
      rule_type                  = "Basic"
      http_listener_name         = "httpListener"
      backend_address_pool_name  = "backendPool"
      backend_http_settings_name = "backendHttpSettings"
      priority                   = 100
    }
  }

  # SSL Certificate from Key Vault (if Key Vault is configured)
  dynamic "ssl_certificate" {
    for_each = var.key_vault_secret_id != null && var.ssl_certificate_name != null ? [1] : []
    content {
      name                = var.ssl_certificate_name
      key_vault_secret_id = var.key_vault_secret_id
    }
  }

  # SSL Certificate from data (legacy - if provided directly)
  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate_data != null ? [1] : []
    content {
      name     = "sslCert"
      data     = var.ssl_certificate_data
      password = var.ssl_certificate_password
    }
  }

  # HTTPS Listener (uses SSL certificate from Key Vault or direct upload)
  # Only created when NOT using custom backend settings
  dynamic "http_listener" {
    for_each = ((var.key_vault_secret_id != null && var.ssl_certificate_name != null) || var.ssl_certificate_data != null) && length(var.backend_http_settings_list) == 0 ? [1] : []
    content {
      name                           = "httpsListener"
      frontend_ip_configuration_name = "appGatewayFrontendIP"
      frontend_port_name             = "httpsPort"
      protocol                       = "Https"
      ssl_certificate_name           = var.key_vault_secret_id != null && var.ssl_certificate_name != null ? var.ssl_certificate_name : "sslCert"
      require_sni                    = false # Set to true if you need SNI for multiple domains
    }
  }

  # Custom HTTP Listeners (from variable)
  dynamic "http_listener" {
    for_each = var.http_listeners_list
    content {
      name                           = http_listener.key
      frontend_ip_configuration_name = "appGatewayFrontendIP"
      frontend_port_name             = http_listener.value.frontend_port_name
      protocol                       = http_listener.value.protocol
      ssl_certificate_name           = http_listener.value.ssl_certificate_name
      require_sni                    = http_listener.value.require_sni
      host_name                      = length(http_listener.value.host_names) == 1 ? http_listener.value.host_names[0] : http_listener.value.host_name
      host_names                     = length(http_listener.value.host_names) > 1 ? http_listener.value.host_names : null
    }
  }

  # HTTPS Routing Rule (routes HTTPS traffic to backend using HTTPS)
  # Only created when NOT using custom backend settings
  dynamic "request_routing_rule" {
    for_each = ((var.key_vault_secret_id != null && var.ssl_certificate_name != null) || var.ssl_certificate_data != null) && length(var.backend_http_settings_list) == 0 ? [1] : []
    content {
      name                       = "httpsRoutingRule"
      rule_type                  = "Basic"
      http_listener_name         = "httpsListener"
      backend_address_pool_name  = "backendPool"
      backend_http_settings_name = "backendHttpSettings"
      priority                   = 200
    }
  }

  # Custom Request Routing Rules (from variable)
  dynamic "request_routing_rule" {
    for_each = var.request_routing_rules_list
    content {
      name                       = request_routing_rule.key
      rule_type                  = request_routing_rule.value.rule_type
      http_listener_name         = request_routing_rule.value.http_listener_name
      backend_address_pool_name  = request_routing_rule.value.backend_address_pool_name
      backend_http_settings_name = request_routing_rule.value.backend_http_settings_name
      priority                   = request_routing_rule.value.priority
    }
  }

  # SSL Policy - Use modern TLS 1.2+ (avoid deprecated TLS 1.0/1.1)
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101" # TLS 1.2+ with strong ciphers
  }

  # WAF Configuration (if enabled)
  dynamic "waf_configuration" {
    for_each = var.enable_waf ? [1] : []
    content {
      enabled          = true
      firewall_mode    = var.waf_firewall_mode
      rule_set_type    = var.waf_rule_set_type
      rule_set_version = var.waf_rule_set_version
    }
  }

  tags = var.tags

  depends_on = [azurerm_public_ip.appgw_pip]
}
