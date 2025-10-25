# Application Gateway Module Variables

variable "appgw_name" {
  type        = string
  description = "Name of the Application Gateway"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet for Application Gateway"
}

variable "backend_ip_addresses" {
  type        = list(string)
  description = "List of backend IP addresses for the Application Gateway"
  default     = []
}

variable "sku_name" {
  type        = string
  description = "SKU name for Application Gateway"
  default     = "WAF_v2"
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.sku_name)
    error_message = "The sku_name must be either Standard_v2 or WAF_v2."
  }
}

variable "sku_tier" {
  type        = string
  description = "SKU tier for Application Gateway"
  default     = "WAF_v2"
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.sku_tier)
    error_message = "The sku_tier must be either Standard_v2 or WAF_v2."
  }
}

variable "capacity" {
  type        = number
  description = "Capacity (number of instances) for Application Gateway"
  default     = 2
  validation {
    condition     = var.capacity >= 1 && var.capacity <= 125
    error_message = "The capacity must be between 1 and 125."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for Application Gateway"
  default     = ["1", "2", "3"]
}

variable "enable_waf" {
  type        = bool
  description = "Enable Web Application Firewall"
  default     = true
}

variable "waf_firewall_mode" {
  type        = string
  description = "WAF firewall mode"
  default     = "Detection"
  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_firewall_mode)
    error_message = "The waf_firewall_mode must be either Detection or Prevention."
  }
}

variable "waf_rule_set_type" {
  type        = string
  description = "WAF rule set type"
  default     = "OWASP"
}

variable "waf_rule_set_version" {
  type        = string
  description = "WAF rule set version"
  default     = "3.2"
}

variable "health_probe_host" {
  type        = string
  description = "Host for health probe"
  default     = "127.0.0.1"
}

variable "ssl_certificate_data" {
  type        = string
  description = "SSL certificate data (base64 encoded)"
  default     = null
  sensitive   = true
}

variable "ssl_certificate_password" {
  type        = string
  description = "SSL certificate password"
  default     = null
  sensitive   = true
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault containing SSL certificates (used for dependencies)"
  default     = null
}

variable "key_vault_secret_id" {
  type        = string
  description = "Full secret ID/URI of the SSL certificate in Key Vault (e.g., https://vault.vault.azure.net/secrets/cert-name)"
  default     = null
}

variable "ssl_certificate_name" {
  type        = string
  description = "Name of the SSL certificate/secret in Key Vault"
  default     = null
}

variable "backend_http_settings_list" {
  type = map(object({
    port                  = number
    protocol              = string
    cookie_based_affinity = string
    request_timeout       = optional(number, 300)
    probe_name            = string
  }))
  description = "Map of backend HTTP settings configurations"
  default     = {}
}

variable "probes_list" {
  type = map(object({
    protocol            = string
    host                = string
    path                = string
    interval            = optional(number, 30)
    timeout             = optional(number, 30)
    unhealthy_threshold = optional(number, 3)
    match_status_codes  = optional(list(string), ["200-399"])
  }))
  description = "Map of health probe configurations"
  default     = {}
}

variable "http_listeners_list" {
  type = map(object({
    protocol             = string
    frontend_port_name   = optional(string, "httpsPort")
    ssl_certificate_name = optional(string)
    require_sni          = optional(bool, true)       # Changed default to true for multi-domain support
    host_names           = optional(list(string), []) # List of domain names (supports multiple domains)
    host_name            = optional(string)           # Single domain (legacy - use host_names instead)
  }))
  description = <<-EOT
    Map of HTTP listener configurations. Each listener can have:
    - protocol: Http or Https
    - frontend_port_name: Name of the frontend port (default: httpsPort)
    - ssl_certificate_name: Name of SSL certificate (required for HTTPS)
    - require_sni: Enable SNI (Server Name Indication) - recommended for multi-domain (default: true)
    - host_names: List of domain names for this listener (recommended approach)
    - host_name: Single domain name (legacy - use host_names instead)
    
    Example:
      {
        "apiListener" = {
          protocol             = "Https"
          ssl_certificate_name = "my-ssl-cert"
          require_sni          = true
          host_names           = ["api.example.com", "api.example.net"]
        }
      }
  EOT
  default     = {}
}

variable "request_routing_rules_list" {
  type = map(object({
    rule_type                  = optional(string, "Basic")
    http_listener_name         = string
    backend_address_pool_name  = string
    backend_http_settings_name = string
    priority                   = number
  }))
  description = "Map of request routing rule configurations"
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "external_identity_id" {
  type        = string
  description = "ID of an externally-created user-assigned managed identity (required)"
}

