##############################################################################
# outputs.tf
# Exposes key resource identifiers and connection details after apply.
##############################################################################

# ─── Resource Group ──────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the resource group containing all PoC resources."
  value       = azurerm_resource_group.main.name
}

# ─── Networking ──────────────────────────────────────────────────────────────

output "vnet_id" {
  description = "Resource ID of the Virtual Network."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network."
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map of subnet name → resource ID for all four subnets."
  value = {
    web         = azurerm_subnet.web.id
    management  = azurerm_subnet.management.id
    application = azurerm_subnet.application.id
    backend     = azurerm_subnet.backend.id
  }
}

# ─── NSG IDs (Coalfire module outputs) ────────────────────────────────────────

output "nsg_ids" {
  description = "Map of subnet name → NSG resource ID (from Coalfire NSG module)."
  value = {
    web         = module.nsg_web.network_security_group_id
    management  = module.nsg_management.network_security_group_id
    application = module.nsg_application.network_security_group_id
    backend     = module.nsg_backend.network_security_group_id
  }
}

# ─── Compute ─────────────────────────────────────────────────────────────────

output "web_vm_private_ips" {
  description = "Private IP addresses of the two web VMs."
  value       = azurerm_network_interface.web[*].private_ip_address
}

output "mgmt_vm_private_ip" {
  description = "Private IP address of the management VM."
  value       = azurerm_network_interface.mgmt.private_ip_address
}

output "availability_set_id" {
  description = "Resource ID of the web VM availability set."
  value       = azurerm_availability_set.web.id
}

# ─── Load Balancer ────────────────────────────────────────────────────────────

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer frontend."
  value       = azurerm_public_ip.lb.ip_address
}

output "load_balancer_fqdn" {
  description = "Fully-qualified domain name of the load balancer public IP (auto-assigned)."
  value       = azurerm_public_ip.lb.fqdn
}

# ─── Storage ─────────────────────────────────────────────────────────────────

output "storage_account_name" {
  description = "Name of the application storage account."
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob service endpoint URL."
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_containers" {
  description = "Names of the two blob containers."
  value = {
    terraformstate = azurerm_storage_container.terraformstate.name
    weblogs        = azurerm_storage_container.weblogs.name
  }
}

# ─── SSH Private Key (PoC only) ───────────────────────────────────────────────
# WARNING: This output exposes the SSH private key in Terraform state.
# For production: provision SSH keys outside Terraform and store in Key Vault.

output "ssh_private_key_pem" {
  description = <<-EOT
    PEM-encoded SSH private key for all VMs.
    SECURITY NOTICE: This key is stored in Terraform state (plaintext).
    Save to a file with permissions 0600. Delete from state after provisioning
    and rotate keys immediately in any non-ephemeral environment.
  EOT
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "ssh_public_key_openssh" {
  description = "OpenSSH public key installed on all VMs."
  value       = tls_private_key.ssh.public_key_openssh
}

# ─── Connection Instructions ─────────────────────────────────────────────────

output "connection_instructions" {
  description = "Quick-reference instructions for connecting to the environment."
  value       = <<-EOT
    ════════════════════════════════════════════════════════
    Azure Web Server PoC – Connection Instructions
    ════════════════════════════════════════════════════════

    1. Extract the SSH private key:
       terraform output -raw ssh_private_key_pem > ~/.ssh/poc_id_rsa
       chmod 0600 ~/.ssh/poc_id_rsa

    2. SSH to the management VM (requires VPN/ExpressRoute or bastion):
       ssh -i ~/.ssh/poc_id_rsa ${var.vm_admin_username}@<mgmt-vm-private-ip>

    3. From the management VM, SSH to a web VM:
       ssh -i ~/.ssh/poc_id_rsa ${var.vm_admin_username}@<web-vm-private-ip>

    4. Test the load balancer:
       curl http://${azurerm_public_ip.lb.ip_address}/
       curl http://${azurerm_public_ip.lb.ip_address}/health

    5. To use the storage account backend for Terraform state, add to
       your root module:
         terraform {
           backend "azurerm" {
             resource_group_name  = "${azurerm_resource_group.main.name}"
             storage_account_name = "${azurerm_storage_account.main.name}"
             container_name       = "terraformstate"
             key                  = "prod.terraform.tfstate"
           }
         }
    ════════════════════════════════════════════════════════
  EOT
}
