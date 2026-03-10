##############################################################################
# ROOT OUTPUTS.TF
##############################################################################

output "resource_group_name" {
  description = "Name of the deployed Resource Group."
  value       = azurerm_resource_group.main.name
}

# ── Network ───────────────────────────────────────────────────────────────────

output "vnet_id" {
  description = "Resource ID of the Virtual Network."
  value       = module.network.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet names to their resource IDs."
  value       = module.network.subnet_ids
}

# ── Compute ───────────────────────────────────────────────────────────────────

output "web_vm_private_ips" {
  description = "Private IP addresses of the Web VMs."
  value       = module.compute.web_vm_private_ips
}

output "management_vm_private_ip" {
  description = "Private IP address of the Management VM."
  value       = module.compute.management_vm_private_ip
}

# ── Load Balancer ─────────────────────────────────────────────────────────────

output "loadbalancer_frontend_ip" {
  description = "Frontend private IP of the internal Load Balancer."
  value       = module.loadbalancer.frontend_private_ip
}

# ── Storage ───────────────────────────────────────────────────────────────────

output "storage_account_name" {
  description = "Name of the deployed Storage Account."
  value       = module.storage.storage_account_name
}

output "storage_account_id" {
  description = "Resource ID of the Storage Account."
  value       = module.storage.storage_account_id
}

# ── Security ──────────────────────────────────────────────────────────────────

output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = module.security.key_vault_uri
}
