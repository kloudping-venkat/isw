# Azure DevOps Agent Installation Guide for Windows VMs

## Overview
Install Azure DevOps agents on WEB, APP, and ADO Windows VMs using VM Extensions and PowerShell scripts. This approach uses Azure Key Vault to securely store the PAT token.

## Steps to Implement

### 1. Store PAT Token in Azure Key Vault ✅

**Add PAT Secret to Key Vault:**
```hcl
# Add to each tier's Key Vault (WEB-KV, APP-KV, ADO-KV)
resource "azurerm_key_vault_secret" "ado_pat_token" {
  name         = "ado-pat-token"
  value        = var.ado_pat_token  # Pass as variable
  key_vault_id = azurerm_key_vault.tier_kv.id
}
```

### 2. Add PAT Variable to Terraform

**In variables.tf:**
```hcl
variable "ado_pat_token" {
  description = "Azure DevOps Personal Access Token for agent registration"
  type        = string
  sensitive   = true
}

variable "ado_organization_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = "https://dev.azure.com/your-org"
}

variable "ado_deployment_group" {
  description = "Azure DevOps deployment group name"
  type        = string
  default     = "BOFA-CS-Servers"
}
```

### 3. Update VM Configuration

**Add to each VM configuration:**
```hcl
virtual_machines = {
  "${local.prefix}-WEB-VM01" = {
    # ... existing config ...
    install_ado_agent = true
    ado_agent_role    = "web-server"
    ado_tags          = "web,iis,frontend"
  }
}
```

### 4. Enhanced VM Extension Script

The compute module already has VM extensions. We'll enhance the PowerShell script to include ADO agent installation.

## Implementation Files Needed

1. **Enhanced compute module variables**
2. **PowerShell script for ADO agent installation**  
3. **Key Vault secret management**
4. **VM configuration updates**

## Security Benefits

✅ **PAT Token Security**: Stored in Azure Key Vault, not in code
✅ **Managed Identity**: VMs use system-assigned identity to access Key Vault
✅ **Deployment Groups**: Agents join specific deployment groups
✅ **Tagging**: Agents tagged by role (web, app, ado) for targeting

## Cost Considerations

- **No additional Azure costs** - uses existing VMs
- **Agent licensing** - Check ADO parallel job limits
- **Key Vault operations** - Minimal cost for secret retrieval

Would you like me to implement this solution step by step?