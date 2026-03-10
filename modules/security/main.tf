##############################################################################
# MODULE: SECURITY
# Provisions:
#   - Azure AD Application + Service Principal + client secret
#   - RBAC role assignments for the SP:
#       Contributor           -> Resource Group scope
#       Storage Blob Data Reader  -> Storage Account scope
#       Key Vault Secrets Officer -> Key Vault scope
#   - Azure Key Vault (RBAC mode, purge-protected)
#   - Key Vault secrets:
#       sp-client-id      -> Service Principal application (client) ID
#       sp-client-secret  -> Service Principal client secret
#       ssh-private-key-web  -> Private key for Web VMs
#       ssh-private-key-mgmt -> Private key for Management VM
#   - User Principal RBAC assignments (Resource Group / Storage / KV scoped)
##############################################################################

data "azurerm_client_config" "current" {}

##############################################################################
# Azure AD Application + Service Principal
##############################################################################

resource "azuread_application" "sp" {
  display_name = var.sp_name
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.sp.client_id
  tags      = ["terraform-managed"]
}

resource "azuread_service_principal_password" "sp" {
  service_principal_id = azuread_service_principal.sp.id

  # Rotate by changing this value and re-applying.
  rotate_when_changed = {
    rotation = "v1"
  }
}

##############################################################################
# Service Principal RBAC Role Assignments
##############################################################################

# Contributor on the Resource Group
resource "azurerm_role_assignment" "sp_contributor" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.sp.object_id
}

# Storage Blob Data Reader on the Storage Account
resource "azurerm_role_assignment" "sp_storage_reader" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_service_principal.sp.object_id
}

# Key Vault Secrets Officer on the Key Vault (assigned after KV is created below)
resource "azurerm_role_assignment" "sp_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azuread_service_principal.sp.object_id
}

##############################################################################
# Key Vault
##############################################################################

resource "azurerm_key_vault" "main" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = var.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.kv_ip_rules
    virtual_network_subnet_ids = []
  }
}

# Terraform executor gets Key Vault Administrator so it can write secrets below.
resource "azurerm_role_assignment" "tf_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Short pause so the RBAC assignment propagates before secret writes are attempted.
resource "time_sleep" "kv_rbac_propagation" {
  create_duration = "30s"
  depends_on      = [azurerm_role_assignment.tf_kv_admin]
}

##############################################################################
# Key Vault Secrets
##############################################################################

resource "azurerm_key_vault_secret" "sp_client_id" {
  name         = "sp-client-id-01"
  value        = azuread_application.sp.client_id
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.kv_rbac_propagation]
}

resource "azurerm_key_vault_secret" "sp_client_secret" {
  name         = "sp-client-secret-01"
  value        = azuread_service_principal_password.sp.value
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.kv_rbac_propagation]
}

resource "azurerm_key_vault_secret" "ssh_private_key_web" {
  name         = "ssh-private-key-web-01"
  value        = var.ssh_private_key_web
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.kv_rbac_propagation]
}

resource "azurerm_key_vault_secret" "ssh_private_key_mgmt" {
  name         = "ssh-private-key-mgmt-01"
  value        = var.ssh_private_key_mgmt
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.kv_rbac_propagation]
}

##############################################################################
# User Principal RBAC Role Assignments
# Iterates over var.user_principals and routes each role to the correct scope.
##############################################################################

locals {
  rg_role_assignments = flatten([
    for name, principal in var.user_principals : [
      for role in principal.roles : {
        key       = "${name}-${role}"
        object_id = principal.object_id
        role      = role
      }
      if !contains([
        "Key Vault Secrets Officer", "Key Vault Secrets User",
        "Key Vault Administrator", "Key Vault Reader",
        "Storage Blob Data Reader", "Storage Blob Data Contributor",
        "Storage Blob Data Owner", "Storage Queue Data Contributor"
      ], role)
    ]
  ])

  storage_role_assignments = flatten([
    for name, principal in var.user_principals : [
      for role in principal.roles : {
        key       = "${name}-${role}"
        object_id = principal.object_id
        role      = role
      }
      if contains([
        "Storage Blob Data Reader", "Storage Blob Data Contributor",
        "Storage Blob Data Owner", "Storage Queue Data Contributor"
      ], role)
    ]
  ])

  kv_role_assignments = flatten([
    for name, principal in var.user_principals : [
      for role in principal.roles : {
        key       = "${name}-${role}"
        object_id = principal.object_id
        role      = role
      }
      if contains([
        "Key Vault Secrets Officer", "Key Vault Secrets User",
        "Key Vault Administrator", "Key Vault Reader",
        "Key Vault Certificates Officer"
      ], role)
    ]
  ])
}

resource "azurerm_role_assignment" "user_rg" {
  for_each = { for ra in local.rg_role_assignments : ra.key => ra }

  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = each.value.role
  principal_id         = each.value.object_id
}

resource "azurerm_role_assignment" "user_storage" {
  for_each = { for ra in local.storage_role_assignments : ra.key => ra }

  scope                = var.storage_account_id
  role_definition_name = each.value.role
  principal_id         = each.value.object_id
}

resource "azurerm_role_assignment" "user_kv" {
  for_each = { for ra in local.kv_role_assignments : ra.key => ra }

  scope                = azurerm_key_vault.main.id
  role_definition_name = each.value.role
  principal_id         = each.value.object_id
  depends_on           = [time_sleep.kv_rbac_propagation]
}
