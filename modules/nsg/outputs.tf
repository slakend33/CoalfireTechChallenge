##############################################################################
# MODULE: NSG – OUTPUTS
##############################################################################

output "web_nsg_id" {
  description = "Resource ID of the Web NSG."
  value       = azurerm_network_security_group.web.id
}

output "management_nsg_id" {
  description = "Resource ID of the Management NSG."
  value       = azurerm_network_security_group.management.id
}
