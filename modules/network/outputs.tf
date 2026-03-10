##############################################################################
# MODULE: NETWORK – OUTPUTS
##############################################################################

output "vnet_id" {
  description = "Resource ID of the VNet."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the VNet."
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map of subnet logical name to resource ID."
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "subnet_address_prefixes" {
  description = "Map of subnet logical name to address prefix."
  value       = { for k, v in azurerm_subnet.subnets : k => v.address_prefixes[0] }
}
