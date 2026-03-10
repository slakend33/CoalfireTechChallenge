##############################################################################
# compute.tf
# Provisions:
#   • SSH key pair (TLS resource – PoC only; use Key Vault in production)
#   • Availability Set for the two web VMs
#   • 2 × Linux web VMs in the web subnet, joined to the availability set
#   • 1 × Linux management VM in the management subnet
#
# NOTE: Coalfire does not currently publish a public terraform-azurerm-vm-linux
# module, so native azurerm_linux_virtual_machine resources are used.
# The Windows equivalent is available at:
#   github.com/Coalfire-CF/terraform-azurerm-vm-windows
##############################################################################

# ─── SSH Key Pair ─────────────────────────────────────────────────────────────
# Generates a 4096-bit RSA key for SSH authentication on all VMs.
# WARNING: The private key is stored in Terraform state. For production
# environments, provision the key externally and reference it via a variable
# or inject it from Azure Key Vault.

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ─── Availability Set ─────────────────────────────────────────────────────────
# Ensures the two web VMs are distributed across separate fault and update
# domains, protecting against both planned and unplanned outages.

resource "azurerm_availability_set" "web" {
  name                         = "${local.name_prefix}-web-avset"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true   # Required for managed-disk VMs
  tags                         = local.common_tags
}

# ─── Web VM Network Interfaces ────────────────────────────────────────────────

resource "azurerm_network_interface" "web" {
  count               = 2
  name                = "${local.name_prefix}-web-vm${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ─── Web Virtual Machines ─────────────────────────────────────────────────────
# Two Linux VMs running in the web subnet, both members of the availability set.
# Nginx is installed via cloud-init to serve as a basic web server.

resource "azurerm_linux_virtual_machine" "web" {
  count                           = 2
  name                            = "${local.name_prefix}-web-vm${count.index + 1}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size_web
  admin_username                  = var.vm_admin_username
  availability_set_id             = azurerm_availability_set.web.id
  disable_password_authentication = true
  tags                            = merge(local.common_tags, { Role = "WebServer", Index = tostring(count.index + 1) })

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    name                 = "${local.name_prefix}-web-vm${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.linux_image.publisher
    offer     = var.linux_image.offer
    sku       = var.linux_image.sku
    version   = var.linux_image.version
  }

  # Cloud-init: installs nginx and configures a simple health-check page.
  # The custom_data value is base64-encoded by Terraform automatically.
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
      - echo "<h1>Web VM ${count.index + 1} – ${local.name_prefix}</h1>" > /var/www/html/index.html
      - echo "OK" > /var/www/html/health
  CLOUDINIT
  )

  boot_diagnostics {
    # Passing no storage_uri uses Azure-managed boot diagnostics storage
    # (no extra storage account needed for this purpose).
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.web,
  ]
}

# ─── Management VM Network Interface ─────────────────────────────────────────

resource "azurerm_network_interface" "mgmt" {
  name                = "${local.name_prefix}-mgmt-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ─── Management Virtual Machine ───────────────────────────────────────────────
# Single Linux VM in the management subnet. Acts as a jump host for SSH access
# to the web VMs and as the only principal with storage account access.

resource "azurerm_linux_virtual_machine" "mgmt" {
  name                            = "${local.name_prefix}-mgmt-vm"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size_mgmt
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  tags                            = merge(local.common_tags, { Role = "Management" })

  network_interface_ids = [
    azurerm_network_interface.mgmt.id,
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    name                 = "${local.name_prefix}-mgmt-vm-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.linux_image.publisher
    offer     = var.linux_image.offer
    sku       = var.linux_image.sku
    version   = var.linux_image.version
  }

  # Cloud-init: installs management utilities and the Azure CLI.
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - curl
      - jq
      - unzip
      - azure-cli
    runcmd:
      - echo "Management VM provisioned by Terraform" >> /etc/motd
  CLOUDINIT
  )

  boot_diagnostics {}

  depends_on = [
    azurerm_subnet_network_security_group_association.management,
  ]
}

# ─── Load Balancer → Web VM Backend Pool Association ─────────────────────────
# Registers each web VM NIC's IP configuration into the LB backend pool
# (defined in loadbalancer.tf).

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}
