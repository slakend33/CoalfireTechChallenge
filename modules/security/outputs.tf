##############################################################################
# MODULE: SECURITY - OUTPUTS
##############################################################################

# -- Key Vault -----------------------------------------------------------------

output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.main.name
}

# -- Service Principal ---------------------------------------------------------

output "service_principal_client_id" {
  description = "Application (client) ID of the Service Principal."
  value       = azuread_application.sp.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the Service Principal (used for additional role assignments)."
  value       = azuread_service_principal.sp.object_id
}

output "service_principal_tenant_id" {
  description = "Tenant ID the Service Principal belongs to."
  value       = data.azurerm_client_config.current.tenant_id
}
