output "rg_name" {
  description = "The name of the created Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "location" {
  description = "The location of the Resource Group"
  value       = azurerm_resource_group.rg.location
}
