# VNet Peering Module Variables

variable "local_vnet_name" {
  description = "Name of the local VNet to peer from"
  type        = string
}

variable "local_resource_group_name" {
  description = "Resource group name of the local VNet"
  type        = string
}

variable "aadds_vnet_name" {
  description = "Name of the Azure AD Domain Services VNet to peer to"
  type        = string
}

variable "aadds_vnet_resource_group" {
  description = "Resource group name of the Azure AD Domain Services VNet"
  type        = string
}

variable "tags" {
  description = "Tags to apply to peering resources"
  type        = map(string)
  default     = {}
}