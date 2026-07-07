output "db_id"       { value = azurerm_postgresql_flexible_server.main.id }
output "db_fqdn"     { value = azurerm_postgresql_flexible_server.main.fqdn }
output "redis_id"    { value = azurerm_redis_cache.main.id }
output "redis_hostname" { value = azurerm_redis_cache.main.hostname }
output "redis_primary_access_key" {
  value     = azurerm_redis_cache.main.primary_access_key
  sensitive = true
}
