# =============================================================================
#  Module: database
#  Creates: PostgreSQL 16 Flexible Server, Redis Cache, private endpoint
#  Resource naming: adidas-prod-psql, adidas-prod-redis
# =============================================================================

# ── PostgreSQL 16 Flexible Server ────────────────────────────────────────────
resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "${var.name_prefix}-psql"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "16"
  administrator_login           = var.db_admin_username
  administrator_password        = var.db_admin_password
  sku_name                      = var.db_sku
  storage_mb                    = var.db_storage_mb
  storage_tier                  = "P30"
  backup_retention_days         = 35
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  zone                          = "1"

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  tags = var.tags
}

# ── PostgreSQL security configurations ────────────────────────────────────────
resource "azurerm_postgresql_flexible_server_configuration" "ssl" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttle" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# ── Application database ──────────────────────────────────────────────────────
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ── Redis Cache ───────────────────────────────────────────────────────────────
resource "azurerm_redis_cache" "main" {
  name                          = "${var.name_prefix}-redis"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
}

# ── Redis private endpoint ────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "redis" {
  name                = "${var.name_prefix}-pe-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.redis_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-psc-redis"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.redis_dns_zone_id]
  }
}
