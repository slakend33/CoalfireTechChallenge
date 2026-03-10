##############################################################################
# MODULE: LOADBALANCER
# Internal (private) Azure Load Balancer for the Web VMs.
# Frontend IP is allocated from the Web subnet address space.
##############################################################################

# -- Load Balancer -------------------------------------------------------------

resource "azurerm_lb" "web" {
  name                = var.lb_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  # Standard SKU internal LBs require Static allocation with an explicit IP.
  # The IP must fall within the web subnet address range (default: 10.0.4.0/24).
  frontend_ip_configuration {
    name                          = "frontend-web"
    subnet_id                     = var.web_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.lb_frontend_private_ip
  }
}

# -- Backend Address Pool ------------------------------------------------------

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "bepool-web"
  loadbalancer_id = azurerm_lb.web.id
}

# -- Associate each Web VM NIC with the backend pool ---------------------------

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count = length(var.web_vm_nic_ids)

  network_interface_id    = var.web_vm_nic_ids[count.index]
  ip_configuration_name   = "ipconfig-web-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

# -- Health Probe (HTTP on port 80) --------------------------------------------

resource "azurerm_lb_probe" "http" {
  name            = "probe-http"
  loadbalancer_id = azurerm_lb.web.id
  protocol        = "Http"
  port            = 80
  request_path    = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# -- Load Balancing Rules ------------------------------------------------------

resource "azurerm_lb_rule" "http" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-web"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default"
}

resource "azurerm_lb_rule" "https" {
  name                           = "rule-https"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend-web"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default"
}
