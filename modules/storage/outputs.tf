##############################################################################
# MODULE: STORAGE - OUTPUTS
##############################################################################

output "storage_account_id" {
  description = "Resource ID of the Storage Account."
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "Primary blob service endpoint."
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "terraformstate_container_name" {
  description = "Name of the Terraform state container."
  value       = azurerm_storage_container.terraformstate.name
}

output "weblogs_container_name" {
  description = "Name of the web logs container."
  value       = azurerm_storage_container.weblogs.name
}
