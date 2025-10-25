# Storage Scripts Module Variables

variable "storage_account_name" {
  description = "Name of the storage account for PowerShell scripts"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
  type        = string
}

variable "container_name" {
  description = "Name of the blob container for scripts"
  type        = string
  default     = "powershell-scripts"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs that are allowed to access the storage account"
  type        = list(string)
  default     = []
}

variable "scripts_path" {
  description = "Base path to PowerShell scripts directory"
  type        = string
  default     = "powershell"
}