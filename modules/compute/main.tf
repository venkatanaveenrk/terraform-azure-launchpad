# =============================================================================
#  Module: compute
#  Creates: Linux VMs (Ubuntu 24.04), Application Gateway WAF v2, Public IP
#  Resource naming: adidas-prod-vm1, adidas-prod-agw, adidas-prod-pip-agw
#  Note: No public IP on VMs. Access via VPN/jump host — user's choice.
# =============================================================================

# ── Public IP for Application Gateway ────────────────────────────────────────
resource "azurerm_public_ip" "agw" {
  name                = "${var.name_prefix}-pip-agw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ── Application Gateway WAF v2 ────────────────────────────────────────────────
# Not zone-redundant (avoids the zonal cost premium) — HA is achieved instead
# via a minimum of 2 autoscale instances, which keeps the gateway available
# through a single instance failure.
resource "azurerm_application_gateway" "main" {
  name                = "${var.name_prefix}-agw"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = var.agw_capacity
    max_capacity = var.agw_capacity * 4
  }

  waf_configuration {
    enabled                  = true
    firewall_mode            = "Prevention"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    file_upload_limit_mb     = 100
    max_request_body_size_kb = 128
    request_body_check       = true
  }

  gateway_ip_configuration {
    name      = "agw-ip-config"
    subnet_id = var.agw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "agw-frontend-public"
    public_ip_address_id = azurerm_public_ip.agw.id
  }

  frontend_port {
    name = "port-http"
    port = 80
  }

  backend_address_pool {
    name         = "pool-vms"
    ip_addresses = azurerm_network_interface.vm[*].private_ip_address
  }

  backend_http_settings {
    name                  = "http-settings-app"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "probe-health"
  }

  probe {
    name                = "probe-health"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200-399"]
    }
  }

  # HTTP listener — SSL is terminated upstream (domain/CDN provider), AGW serves plain HTTP
  http_listener {
    name                           = "listener-http"
    frontend_ip_configuration_name = "agw-frontend-public"
    frontend_port_name             = "port-http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-http"
    rule_type                  = "Basic"
    http_listener_name         = "listener-http"
    backend_address_pool_name  = "pool-vms"
    backend_http_settings_name = "http-settings-app"
    priority                   = 10
  }
}

# ── Network Interfaces (one per VM) ──────────────────────────────────────────
resource "azurerm_network_interface" "vm" {
  count               = var.vm_count
  name                = "${var.name_prefix}-nic-vm${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.vm_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# ── Linux VMs (Ubuntu 24.04 LTS) ──────────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "${var.name_prefix}-vm${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_sku
  zone                = tostring((count.index % 3) + 1)
  tags                = var.tags

  network_interface_ids           = [azurerm_network_interface.vm[count.index].id]
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.name_prefix}-osdisk-vm${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  boot_diagnostics {}

  patch_mode            = "AutomaticByPlatform"
  patch_assessment_mode = "AutomaticByPlatform"

  custom_data = filebase64("${path.module}/cloud-init.yml")
}
