##############################################################################
# MODULE: NSG
# Creates NSG rules:
#   - Allow SSH (TCP/22) from the Management VM to Web VMs.
#   - Allow HTTP/HTTPS (TCP/80,443) from the internal Load Balancer.
#   - Deny all other inbound traffic.
# Associates the NSG with the Web subnet.
##############################################################################

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # ── Allow SSH from Management VM ─────────────────────────────────────────
  security_rule {
    name                       = "Allow-SSH-From-Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.management_vm_private_ip
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow SSH only from the Management VM private IP."
  }

  # ── Allow HTTP from Load Balancer ─────────────────────────────────────────
  security_rule {
    name                       = "Allow-HTTP-From-LoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.loadbalancer_frontend_ip
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow HTTP traffic forwarded by the internal Load Balancer."
  }

  # ── Allow HTTPS from Load Balancer ────────────────────────────────────────
  security_rule {
    name                       = "Allow-HTTPS-From-LoadBalancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.loadbalancer_frontend_ip
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow HTTPS traffic forwarded by the internal Load Balancer."
  }

  # ── Allow Azure Load Balancer health probes ───────────────────────────────
  security_rule {
    name                       = "Allow-AzureLoadBalancer-Probe"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    description                = "Allow Azure LB health probe traffic (required)."
  }

  # ── Deny all other inbound traffic ────────────────────────────────────────
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other inbound traffic. No external access."
  }
}

# ── Management subnet NSG ─────────────────────────────────────────────────────

resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow SSH inbound to Management subnet (restricted – tighten source as needed)
  security_rule {
    name                       = "Allow-SSH-Inbound-Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "Allow SSH within VNet to Management VM."
  }

  security_rule {
    name                       = "Deny-All-Inbound-Mgmt"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other inbound to Management subnet."
  }
}

# ── NSG ↔ Subnet Associations ─────────────────────────────────────────────────

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = var.web_subnet_id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = var.management_subnet_id
  network_security_group_id = azurerm_network_security_group.management.id
}
