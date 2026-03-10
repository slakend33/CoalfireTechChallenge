##############################################################################
# ROOT OUTPUTS.TF
##############################################################################

output "resource_group_name" {
  description = "Name of the deployed Resource Group."
  value       = azurerm_resource_group.main.name
}

# -- Network ------------------------------------------------------------------

output "vnet_id" {
  description = "Resource ID of the Virtual Network."
  value       = module.network.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet names to resource IDs."
  value       = module.network.subnet_ids
}

# -- Compute ------------------------------------------------------------------

output "web_vm_private_ips" {
  description = "Private IP addresses of the Web VMs."
  value       = module.compute.web_vm_private_ips
}

output "management_vm_private_ip" {
  description = "Private IP address of the Management VM."
  value       = module.compute.management_vm_private_ip
}

# -- SSH Keys -----------------------------------------------------------------
# Private keys are stored in Key Vault. Public keys are surfaced here for
# reference (e.g. to add to a bastion or jump host).

output "ssh_public_key_web" {
  description = "OpenSSH public key used by the Web VMs."
  value       = tls_private_key.web.public_key_openssh
}

output "ssh_public_key_mgmt" {
  description = "OpenSSH public key used by the Management VM."
  value       = tls_private_key.mgmt.public_key_openssh
}

# -- Load Balancer ------------------------------------------------------------

output "loadbalancer_frontend_ip" {
  description = "Frontend private IP of the internal Load Balancer."
  value       = module.loadbalancer.frontend_private_ip
}

# -- Storage ------------------------------------------------------------------

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = module.storage.storage_account_name
}

output "storage_account_id" {
  description = "Resource ID of the Storage Account."
  value       = module.storage.storage_account_id
}

# -- Security -----------------------------------------------------------------

output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = module.security.key_vault_uri
}

output "service_principal_client_id" {
  description = "Application (client) ID of the Service Principal."
  value       = module.security.service_principal_client_id
}

output "service_principal_object_id" {
  description = "Object ID of the Service Principal."
  value       = module.security.service_principal_object_id
}

output "service_principal_tenant_id" {
  description = "Tenant ID of the Service Principal."
  value       = module.security.service_principal_tenant_id
}
