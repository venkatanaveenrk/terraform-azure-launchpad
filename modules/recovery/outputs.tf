output "recovery_vault_id" { value = azurerm_recovery_services_vault.main.id }
output "recovery_vault_name" { value = azurerm_recovery_services_vault.main.name }
output "backup_policy_id" { value = azurerm_backup_policy_vm.main.id }

output "dr_resource_group_name" {
  value = var.enable_dr_replication ? azurerm_resource_group.dr[0].name : null
}

output "dr_vnet_id" {
  value = var.enable_dr_replication ? azurerm_virtual_network.dr[0].id : null
}
