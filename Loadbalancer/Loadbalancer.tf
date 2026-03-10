##############################################################################
# loadbalancer.tf
# Creates a public-facing Azure Standard Load Balancer that distributes
# inbound HTTP (port 80) and HTTPS (port 443) traffic across the two web VMs
# in the availability set.
#
# Components:
#   • Public IP address (Standard SKU, zone-redundant)
#   • Load Balancer (Standard SKU)
#   • Backend Address Pool – web VMs register their NICs here (see compute.tf)
#   • Health Probe – monitors /health on port 80
#   • LB Rule (HTTP)  – 0.0.0.0:80  → backend pool port 80
#   • LB Rule (HTTPS) – 0.0.0.0:443 → backend pool port 443
#
# NOTE: Coalfire does not currently publish a public
# terraform-azurerm-loadbalancer module, so native azurerm resources are used.
##############################################################################

# ─── Public IP ───────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "lb" {
  name                = "${local.name_prefix}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"    # Must match the LB SKU
  zones               = ["1", "2", "3"]  # Zone-redundant public IP
  tags                = merge(local.common_tags, { Purpose = "LoadBalancerFrontend" })
}

# ─── Load Balancer ───────────────────────────────────────────────────────────

resource "azurerm_lb" "main" {
  name                = "${local.name_prefix}-web-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"   # Required for availability sets + zones
  tags                = merge(local.common_tags, { Purpose = "WebLoadBalancer" })

  frontend_ip_configuration {
    name                 = "PublicIPFrontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

# ─── Backend Address Pool ─────────────────────────────────────────────────────
# Web VM NICs are associated to this pool in compute.tf via
# azurerm_network_interface_backend_address_pool_association.

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "${local.name_prefix}-web-bepool"
  loadbalancer_id = azurerm_lb.main.id
}

# ─── Health Probe ─────────────────────────────────────────────────────────────
# Monitors GET /health on port 80.  A VM is removed from rotation if 2
# consecutive probes fail (interval 15 s, threshold 2 = 30 s detection window).

resource "azurerm_lb_probe" "http_health" {
  name                = "${local.name_prefix}-http-probe"
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# ─── Load Balancing Rules ─────────────────────────────────────────────────────

# HTTP rule – port 80
resource "azurerm_lb_rule" "http" {
  name                           = "${local.name_prefix}-http-rule"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http_health.id
  idle_timeout_in_minutes        = 4
  enable_tcp_reset               = true
  disable_outbound_snat          = true   # Use separate outbound rule for SNAT
}

# HTTPS rule – port 443
resource "azurerm_lb_rule" "https" {
  name                           = "${local.name_prefix}-https-rule"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PublicIPFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http_health.id
  idle_timeout_in_minutes        = 4
  enable_tcp_reset               = true
  disable_outbound_snat          = true
}

# ─── Outbound Rule ────────────────────────────────────────────────────────────
# Required when disable_outbound_snat = true on LB rules.
# Allows web VMs to reach the internet for package updates, etc.

resource "azurerm_lb_outbound_rule" "web" {
  name                    = "${local.name_prefix}-web-outbound"
  loadbalancer_id         = azurerm_lb.main.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = "PublicIPFrontend"
  }
}
