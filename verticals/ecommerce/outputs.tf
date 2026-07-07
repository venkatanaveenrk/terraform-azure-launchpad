output "resource_group_name" {
  description = "Name of the resource group containing all resources."
  value       = azurerm_resource_group.main.name
}

output "app_gateway_public_ip" {
  description = "Public IP of the Application Gateway. Point your DNS/CDN origin here and terminate SSL there."
  value       = module.compute.agw_public_ip
}

output "vm_private_ips" {
  description = "Private IP addresses of the application VMs."
  value       = module.compute.vm_private_ips
}

output "db_fqdn" {
  description = "PostgreSQL flexible server FQDN. Use in your app connection string."
  value       = module.database.db_fqdn
  sensitive   = true
}

output "redis_hostname" {
  description = "Redis Cache hostname. Use in your app for session/cache config."
  value       = module.database.redis_hostname
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault name holding DB/Redis/VM secrets — az keyvault secret show --vault-name <name> --name <secret>"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI holding DB/Redis/VM secrets."
  value       = module.keyvault.key_vault_uri
}

output "recovery_vault_name" {
  description = "Recovery Services Vault name — holds VM backups and (if enabled) Site Recovery replication."
  value       = module.recovery.recovery_vault_name
}

output "dr_resource_group_name" {
  description = "Secondary-region resource group VMs fail over into. Null if enable_dr_replication is false."
  value       = module.recovery.dr_resource_group_name
}

output "next_steps" {
  description = "Post-deploy checklist."
  value       = <<-EOT

    ✅  ${local.name_prefix} infrastructure deployed successfully!

    ─── DNS / SSL ────────────────────────────────────────────────────
    Point your domain/CDN provider's origin at:  ${module.compute.agw_public_ip}
    Terminate SSL at your domain/CDN provider — the Application Gateway serves plain HTTP.

    ─── VM Access ────────────────────────────────────────────────────
    SSH to VMs using the private key matching your vm_ssh_public_key:
      ssh ${var.vm_admin_username}@<vm_private_ip>
    (Connect via VPN or jump host — VMs have no public IP)

    ─── Secrets ──────────────────────────────────────────────────────
    DB/Redis/VM secrets are in Key Vault: ${module.keyvault.key_vault_name}
      az keyvault secret show --vault-name ${module.keyvault.key_vault_name} --name db-connection-string

    ─── Backup & DR ──────────────────────────────────────────────────
    VM backups + (if enabled) Site Recovery replication: ${module.recovery.recovery_vault_name}
    See docs/disaster-recovery.md for restore/failover steps.

    ─── Full guide ───────────────────────────────────────────────────
    docs/post-deploy.md
  EOT
}
