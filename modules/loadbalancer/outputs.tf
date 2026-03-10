##############################################################################
# MODULE: LOADBALANCER – OUTPUTS
##############################################################################

output "lb_id" {
  description = "Resource ID of the Load Balancer."
  value       = azurerm_lb.web.id
}

output "frontend_private_ip" {
  description = "Dynamically assigned private IP of the LB frontend (used in NSG rules)."
  value       = azurerm_lb.web.frontend_ip_configuration[0].private_ip_address
}

output "backend_pool_id" {
  description = "Resource ID of the backend address pool."
  value       = azurerm_lb_backend_address_pool.web.id
}
