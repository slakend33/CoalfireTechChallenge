##############################################################################
# MODULE: SECURITY
# Provisions:
#   - Azure Key Vault (with RBAC authorization model)
#   - User Principal role assignments (RBAC) on the Resource Group
#   - User Principal role assignments on the Storage Account
#   - User Principal Key Vault role assignments
##############################################################################

data "azurerm_client_config" "current" {}

# ── Key Vault ─────────────────────────────────────────────────────────────────

resource "azurerm_key_vault" "main" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true   # Use RBAC instead of access policies
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    # Add allowed IP ranges or VNet service endpoints here as needed.
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

# ── Terraform executor gets Key Vault Administrator on the vault ──────────────

resource "azurerm_role_assignment" "tf_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

##############################################################################
# User Principal – Resource Group RBAC role assignments
# Iterates over all entries in var.user_principals and assigns each listed role.
##############################################################################

locals {
  # Flatten the list so we can iterate over (principal, role) pairs.
  rg_role_assignments = flatten([
    for name, principal in var.user_principals : [
      for role in principal.roles : {
        key       = "${name}-${role}"
        object_id = principal.object_id
        role      = role
      }
      # Only assign roles that are scoped to the resource group level.
      if !contains(["Key Vault Secrets Officer", "Key Vault Secrets User",
        "Key Vault Administrator", "Key Vault Reader",
      "Storage Blob Data Reader", "Storage Blob Data Contributor"], role)
    ]
  ])

  # Storage account scoped roles
  storage_role_assignments = flatten([
    for name, principal in var.user_principals : [
      for role in principal.roles : {
        key       = "${name}-${role}"
        object_id = principal.object_id
        role      = role
      }
      if contains(["Storage Blob Data Reader", "Storage Blob Data Contributor",
      "Storage Blob Data Owner", "Storage Queue Data Contributor"], role)
    ]
  ])

  # Key Vault scoped roles
  kv_role_assignments = flatten([
    for name, principal in var.user_principals : [
      for role in principal.roles : {
        key       = "${name}-${role}"
        object_id = principal.object_id
        role      = role
      }
      if contains(["Key Vault Secrets Officer", "Key Vault Secrets User",
        "Key Vault Administrator", "Key Vault Reader",
      "Key Vault Certificates Officer"], role)
    ]
  ])
}

# Resource Group scoped role assignments
resource "azurerm_role_assignment" "user_rg" {
  for_each = { for ra in local.rg_role_assignments : ra.key => ra }

  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = each.value.role
  principal_id         = each.value.object_id
}

# Storage Account scoped role assignments
resource "azurerm_role_assignment" "user_storage" {
  for_each = { for ra in local.storage_role_assignments : ra.key => ra }

  scope                = var.storage_account_id
  role_definition_name = each.value.role
  principal_id         = each.value.object_id
}

# Key Vault scoped role assignments
resource "azurerm_role_assignment" "user_kv" {
  for_each = { for ra in local.kv_role_assignments : ra.key => ra }

  scope                = azurerm_key_vault.main.id
  role_definition_name = each.value.role
  principal_id         = each.value.object_id
}
