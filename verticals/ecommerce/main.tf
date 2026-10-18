terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.80"
    }
  }

  # Uncomment and fill these 4 values to store state remotely (recommended for teams)
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstateXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "ecommerce/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# ── Resource group ────────────────────────────────────────────────────────────
# Example: customer=contoso, environment=prod → contoso-prod-rg
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_management_lock" "main" {
  name       = "${local.name_prefix}-lock"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "Managed by azure-infra-quickstart. Remove this lock before running terraform destroy."
}

# ── Networking ────────────────────────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

# ── Database (PostgreSQL + Redis) ─────────────────────────────────────────────
module "database" {
  source = "../../modules/database"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  db_sku              = local.sz.db_sku
  db_storage_mb       = local.sz.db_storage_mb
  db_admin_username   = var.db_admin_username
  db_admin_password   = var.db_admin_password
  delegated_subnet_id = module.networking.db_subnet_id
  private_dns_zone_id = module.networking.db_private_dns_zone_id
  redis_capacity      = local.sz.redis_capacity
  redis_family        = local.sz.redis_family
  redis_sku           = local.sz.redis_sku
  redis_subnet_id     = module.networking.redis_subnet_id
  redis_dns_zone_id   = module.networking.redis_private_dns_zone_id

  depends_on = [module.networking]
}

# ── Compute (VMs + Application Gateway) ──────────────────────────────────────
module "compute" {
  source = "../../modules/compute"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  vm_sku              = local.sz.vm_sku
  vm_count            = local.sz.vm_count
  vm_admin_username   = var.vm_admin_username
  vm_ssh_public_key   = var.vm_ssh_public_key
  vm_subnet_id        = module.networking.vm_subnet_id
  agw_subnet_id       = module.networking.agw_subnet_id
  agw_capacity        = local.sz.agw_capacity
}

# ── Key Vault (DB/Redis/VM secrets) ──────────────────────────────────────────
module "keyvault" {
  source = "../../modules/keyvault"

  name_prefix              = local.name_prefix
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  tags                     = local.common_tags
  keyvault_subnet_id       = module.networking.keyvault_subnet_id
  keyvault_dns_zone_id     = module.networking.keyvault_private_dns_zone_id
  db_admin_username        = var.db_admin_username
  db_admin_password        = var.db_admin_password
  db_fqdn                  = module.database.db_fqdn
  redis_hostname           = module.database.redis_hostname
  redis_primary_access_key = module.database.redis_primary_access_key
  vm_admin_username        = var.vm_admin_username
  vm_ssh_public_key        = var.vm_ssh_public_key
}

# ── Recovery (Backup + Site Recovery DR) ─────────────────────────────────────
module "recovery" {
  source = "../../modules/recovery"

  name_prefix           = local.name_prefix
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  tags                  = local.common_tags
  vm_count              = local.sz.vm_count
  vm_ids                = module.compute.vm_ids
  vm_nic_ids            = module.compute.vm_nic_ids
  vm_vnet_id            = module.networking.vnet_id
  enable_dr_replication = var.enable_dr_replication
  dr_location           = var.dr_location
}
