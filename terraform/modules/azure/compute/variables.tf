# EM Compute Module Variables
# Variables for Windows Server deployment

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "location" {
  description = "Azure region where the VM will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where VM will be deployed"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "vmadmin"
}

variable "windows_sku" {
  description = "Windows Server SKU"
  type        = string
  default     = "2022-datacenter-azure-edition"
}

variable "os_disk_type" {
  description = "Type of OS disk"
  type        = string
  default     = "Premium_LRS"
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 128
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP to the VM"
  type        = bool
  default     = false
}

variable "allowed_rdp_source" {
  description = "Source IP range allowed for RDP access"
  type        = string
  default     = "VirtualNetwork"
}

variable "key_vault_id" {
  description = "ID of the Key Vault to store VM password"
  type        = string
}

variable "storage_account_uri" {
  description = "URI of storage account for boot diagnostics"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name for tagging and identification"
  type        = string
}

variable "environment_code" {
  description = "Short environment code for computer name (e.g., CS, WM, PROD) - max 4 chars to fit 15 char limit"
  type        = string
  default     = "CS"
}

variable "data_disks" {
  description = "Data disks configuration for the VM"
  type = list(object({
    size_gb      = number
    drive_letter = string
    lun          = number
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "scripts_storage_account_name" {
  description = "Name of the shared storage account containing PowerShell scripts (shared across environment)"
  type        = string
}

variable "scripts_container_name" {
  description = "Name of the container containing PowerShell scripts"
  type        = string
  default     = "vmscripts"
}

variable "scripts_blob_endpoint" {
  description = "Blob endpoint of the shared storage account"
  type        = string
}

variable "enable_vm_extensions" {
  description = "Whether to enable VM extensions for configuration"
  type        = bool
  default     = false
}

# Azure DevOps Agent Configuration
variable "install_ado_agent" {
  description = "Whether to install Azure DevOps agent on this VM"
  type        = bool
  default     = false
}

variable "ado_organization_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = ""
}

variable "ado_deployment_pool" {
  description = "Azure DevOps deployment pool name"
  type        = string
  default     = ""
}

variable "ado_pat_secret_name" {
  description = "Name of the PAT secret in Key Vault"
  type        = string
  default     = "ado-pat-token"
}

variable "ado_pat_token" {
  description = "Azure DevOps PAT token (passed from pipeline)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ado_service_user" {
  description = "Domain gMSA service account for ADO agent (default: CertentEMBOFA.Prod\\svc_appsrv_ado1$)"
  type        = string
  default     = "CertentEMBOFA.Prod\\svc_appsrv_ado1$"
}

variable "ado_service_password" {
  description = "Password for ADO service account"
  type        = string
  sensitive   = true
  default     = ""
}

# Azure DevOps Integration Variables
variable "azdo_org_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/your-org)"
  type        = string
  default     = ""
}

variable "azdo_pat" {
  description = "Azure DevOps Personal Access Token (sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "deployment_group_name" {
  description = "Azure DevOps deployment group name"
  type        = string
  default     = "EM-BOFA-PROD"
}

variable "agent_name" {
  description = "Agent display name (defaults to VM hostname if not specified)"
  type        = string
  default     = ""
}

variable "agent_tags" {
  description = "List of tags for agent classification (comma-separated)"
  type        = string
  default     = ""
}

variable "agent_pool" {
  description = "Optional agent pool name (for future use)"
  type        = string
  default     = ""
}

variable "install_agent" {
  description = "Boolean flag to enable/disable agent installation"
  type        = bool
  default     = false
}

# App Server gMSA Configuration
variable "app_service_account" {
  description = "gMSA service account for APP servers (e.g., svc_appsrv_wm$). Will be installed via Install-ADServiceAccount"
  type        = string
  default     = null
}

