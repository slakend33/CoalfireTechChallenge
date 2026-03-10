##############################################################################
# MODULE: COMPUTE - OUTPUTS
##############################################################################

output "web_vm_ids" {
  description = "Resource IDs of the Web VMs."
  value       = azurerm_linux_virtual_machine.web[*].id
}

output "web_vm_private_ips" {
  description = "Private IP addresses of the Web VMs."
  value       = azurerm_network_interface.web[*].private_ip_address
}

output "web_vm_nic_ids" {
  description = "NIC resource IDs for the Web VMs (consumed by the Load Balancer module)."
  value       = azurerm_network_interface.web[*].id
}

output "web_vm_principal_ids" {
  description = "System-assigned managed identity principal IDs of the Web VMs."
  value       = azurerm_linux_virtual_machine.web[*].identity[0].principal_id
}

output "management_vm_id" {
  description = "Resource ID of the Management VM."
  value       = azurerm_linux_virtual_machine.management.id
}

output "management_vm_private_ip" {
  description = "Private IP address of the Management VM."
  value       = azurerm_network_interface.management.private_ip_address
}

output "management_vm_public_ip" {
  description = "Public IP address of the Management VM."
  value       = azurerm_public_ip.management.ip_address
}

output "management_vm_principal_id" {
  description = "System-assigned managed identity principal ID of the Management VM."
  value       = azurerm_linux_virtual_machine.management.identity[0].principal_id
}

output "availability_set_id" {
  description = "Resource ID of the Web VM Availability Set."
  value       = azurerm_availability_set.web.id
}
