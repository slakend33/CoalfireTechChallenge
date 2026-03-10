##############################################################################
# MODULE: COMPUTE
# Resources:
#   - Availability Set for Web VMs
#   - 2x Linux VMs in the Web subnet (Availability Set)
#   - 1x Linux VM in the Management subnet
##############################################################################

locals {
  web_vm_names = [for i in range(var.web_vm_count) : "${var.web_vm_name_prefix}-${format("%02d", i + 1)}"]
}

# ── Availability Set ──────────────────────────────────────────────────────────

resource "azurerm_availability_set" "web" {
  name                         = var.availability_set_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  tags                         = var.tags
}

# ── Web VM NICs ───────────────────────────────────────────────────────────────

resource "azurerm_network_interface" "web" {
  count               = var.web_vm_count
  name                = "nic-${local.web_vm_names[count.index]}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig-web-${count.index}"
    subnet_id                     = var.web_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# ── Web VMs ───────────────────────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "web" {
  count               = var.web_vm_count
  name                = local.web_vm_names[count.index]
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.web.id
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${local.web_vm_names[count.index]}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Disable password authentication – SSH key only
  disable_password_authentication = true

  identity {
    type = "SystemAssigned"
  }
}

# ── Management VM NIC ─────────────────────────────────────────────────────────

resource "azurerm_network_interface" "management" {
  name                = "nic-${var.mgmt_vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig-mgmt"
    subnet_id                     = var.management_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# ── Management VM ─────────────────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "management" {
  name                = var.mgmt_vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.management.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.mgmt_vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  disable_password_authentication = true

  identity {
    type = "SystemAssigned"
  }
}
