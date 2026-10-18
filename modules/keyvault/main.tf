# =============================================================================
#  Module: keyvault
#  Creates: Key Vault (RBAC, private endpoint only) holding DB/Redis/VM secrets
#  Resource naming: contosoprodkv
# =============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  # Key Vault names must be globally unique, 3-24 chars, alphanumeric only
  name                = substr(replace("${var.name_prefix}kv", "-", ""), 0, 24)
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  tags = var.tags
}

# ── Private endpoint — Key Vault is not reachable from the public internet ──
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.name_prefix}-pe-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.keyvault_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.keyvault_dns_zone_id]
  }
}

# ── RBAC: grant the identity running Terraform rights to write secrets ──────
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ── Secrets ───────────────────────────────────────────────────────────────────
# db_admin_username / db_admin_password / vm_ssh_public_key etc. come in as
# variables from the vertical's terraform.tfvars — they are never hardcoded
# here and never touch state anywhere other than these secret values.

resource "azurerm_key_vault_secret" "db_admin_username" {
  name         = "db-admin-username"
  value        = var.db_admin_username
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_admin_password" {
  name         = "db-admin-password"
  value        = var.db_admin_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${var.db_fqdn}/appdb?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = var.redis_hostname
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_primary_access_key" {
  name         = "redis-primary-access-key"
  value        = var.redis_primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "vm-admin-username"
  value        = var.vm_admin_username
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

# Only the public key is ever available to Terraform — the private key is
# generated and held by whoever runs ssh-keygen and never leaves their machine.
resource "azurerm_key_vault_secret" "vm_ssh_public_key" {
  name         = "vm-ssh-public-key"
  value        = var.vm_ssh_public_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}
