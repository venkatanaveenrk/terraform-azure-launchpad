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

    ─── Full guide ───────────────────────────────────────────────────
    docs/post-deploy.md
  EOT
}
