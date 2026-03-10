##############################################################################
# MODULE: STORAGE
# GRS Storage Account with two blob containers:
#   - terraformstate
#   - weblogs
##############################################################################

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"        # Geo-Redundant Storage
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# -- Blob Containers -----------------------------------------------------------

resource "azurerm_storage_container" "terraformstate" {
  name                  = "terraformstate"
  storage_account_name    = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "weblogs" {
  name                  = "weblogs"
  storage_account_name    = azurerm_storage_account.main.name
  container_access_type = "private"
}
