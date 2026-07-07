output "agw_public_ip"  { value = azurerm_public_ip.agw.ip_address }
output "agw_id"         { value = azurerm_application_gateway.main.id }
output "vm_ids"         { value = azurerm_linux_virtual_machine.vm[*].id }
output "vm_private_ips" { value = azurerm_network_interface.vm[*].private_ip_address }
