# =============================================================================
#  Module: recovery
#  Creates: Recovery Services Vault, VM backup policy + protection, and
#           Azure Site Recovery (ASR) cross-region replication for DR failover
#  Resource naming: adidas-prod-rsv, adidas-prod-dr-rg (secondary region)
#
#  Note: ASR resources are order-sensitive in the azurerm provider. If the
#  first `terraform apply` errors on the fabric/container/mapping resources,
#  re-run `terraform apply` — this is a known provider quirk (the vault takes
#  a few minutes to register the ASR resource provider), not a config bug.
# =============================================================================

# ── Recovery Services Vault ───────────────────────────────────────────────────
resource "azurerm_recovery_services_vault" "main" {
  name                = "${var.name_prefix}-rsv"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"

  tags = var.tags
}

# =============================================================================
#  VM Backup
# =============================================================================

resource "azurerm_backup_policy_vm" "main" {
  name                = "${var.name_prefix}-backup-policy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}

resource "azurerm_backup_protected_vm" "main" {
  count               = var.vm_count
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = var.vm_ids[count.index]
  backup_policy_id    = azurerm_backup_policy_vm.main.id
}

# =============================================================================
#  Disaster Recovery — Azure Site Recovery (Azure-to-Azure replication)
# =============================================================================

# Secondary region resource group that replicated VMs fail over into
resource "azurerm_resource_group" "dr" {
  count    = var.enable_dr_replication ? 1 : 0
  name     = "${var.name_prefix}-dr-rg"
  location = var.dr_location
  tags     = var.tags
}

# Secondary region network that replicated VMs attach to on failover
resource "azurerm_virtual_network" "dr" {
  count               = var.enable_dr_replication ? 1 : 0
  name                = "${var.name_prefix}-dr-vnet"
  location            = azurerm_resource_group.dr[0].location
  resource_group_name = azurerm_resource_group.dr[0].name
  address_space       = [var.dr_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "dr_app" {
  count                = var.enable_dr_replication ? 1 : 0
  name                 = "${var.name_prefix}-dr-snet-app"
  resource_group_name  = azurerm_resource_group.dr[0].name
  virtual_network_name = azurerm_virtual_network.dr[0].name
  address_prefixes     = [var.dr_subnet_prefix]
}

# ASR needs a storage account in the source region to stage replication data
resource "azurerm_storage_account" "asr_cache" {
  count                    = var.enable_dr_replication ? 1 : 0
  name                     = substr(replace("${var.name_prefix}asrcache", "-", ""), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_site_recovery_replication_policy" "main" {
  count                                                = var.enable_dr_replication ? 1 : 0
  name                                                 = "${var.name_prefix}-replication-policy"
  resource_group_name                                  = var.resource_group_name
  recovery_vault_name                                  = azurerm_recovery_services_vault.main.name
  recovery_point_retention_in_minutes                  = 24 * 60
  application_consistent_snapshot_frequency_in_minutes = 4 * 60
}

resource "azurerm_site_recovery_fabric" "source" {
  count               = var.enable_dr_replication ? 1 : 0
  name                = "${var.name_prefix}-fabric-source"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  location            = var.location
}

resource "azurerm_site_recovery_fabric" "target" {
  count               = var.enable_dr_replication ? 1 : 0
  name                = "${var.name_prefix}-fabric-target"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  location            = var.dr_location

  depends_on = [azurerm_site_recovery_fabric.source]
}

resource "azurerm_site_recovery_protection_container" "source" {
  count                = var.enable_dr_replication ? 1 : 0
  name                 = "${var.name_prefix}-protcont-source"
  resource_group_name  = var.resource_group_name
  recovery_vault_name  = azurerm_recovery_services_vault.main.name
  recovery_fabric_name = azurerm_site_recovery_fabric.source[0].name
}

resource "azurerm_site_recovery_protection_container" "target" {
  count                = var.enable_dr_replication ? 1 : 0
  name                 = "${var.name_prefix}-protcont-target"
  resource_group_name  = var.resource_group_name
  recovery_vault_name  = azurerm_recovery_services_vault.main.name
  recovery_fabric_name = azurerm_site_recovery_fabric.target[0].name
}

resource "azurerm_site_recovery_protection_container_mapping" "main" {
  count                                     = var.enable_dr_replication ? 1 : 0
  name                                      = "${var.name_prefix}-protcont-mapping"
  resource_group_name                       = var.resource_group_name
  recovery_vault_name                       = azurerm_recovery_services_vault.main.name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.source[0].name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.source[0].name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.target[0].id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.main[0].id
}

resource "azurerm_site_recovery_network_mapping" "main" {
  count                       = var.enable_dr_replication ? 1 : 0
  name                        = "${var.name_prefix}-network-mapping"
  resource_group_name         = var.resource_group_name
  recovery_vault_name         = azurerm_recovery_services_vault.main.name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.source[0].name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.target[0].name
  source_network_id           = var.vm_vnet_id
  target_network_id           = azurerm_virtual_network.dr[0].id
}

# One OS disk per VM, looked up by the well-known name the compute module
# gives it (<name_prefix>-osdisk-vm<N>) — needed because
# azurerm_linux_virtual_machine doesn't expose its own disk ID as an attribute.
data "azurerm_managed_disk" "vm_os_disk" {
  count               = var.enable_dr_replication ? var.vm_count : 0
  name                = "${var.name_prefix}-osdisk-vm${count.index + 1}"
  resource_group_name = var.resource_group_name

  # Data source reads by name (not by ID), so it needs an explicit ordering
  # dependency to guarantee the VM's disk already exists on first apply.
  depends_on = [azurerm_backup_protected_vm.main]
}

resource "azurerm_site_recovery_replicated_vm" "main" {
  count                                     = var.enable_dr_replication ? var.vm_count : 0
  name                                      = "${var.name_prefix}-vm${count.index + 1}-replication"
  resource_group_name                       = var.resource_group_name
  recovery_vault_name                       = azurerm_recovery_services_vault.main.name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.source[0].name
  source_vm_id                              = var.vm_ids[count.index]
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.main[0].id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.source[0].name

  target_resource_group_id                = azurerm_resource_group.dr[0].id
  target_recovery_fabric_id               = azurerm_site_recovery_fabric.target[0].id
  target_recovery_protection_container_id = azurerm_site_recovery_protection_container.target[0].id

  managed_disk {
    disk_id                    = data.azurerm_managed_disk.vm_os_disk[count.index].id
    staging_storage_account_id = azurerm_storage_account.asr_cache[0].id
    target_resource_group_id   = azurerm_resource_group.dr[0].id
    target_disk_type           = "Premium_LRS"
  }

  network_interface {
    source_network_interface_id = var.vm_nic_ids[count.index]
    target_subnet_name          = azurerm_subnet.dr_app[0].name
  }

  depends_on = [
    azurerm_site_recovery_protection_container_mapping.main,
    azurerm_site_recovery_network_mapping.main,
  ]
}
