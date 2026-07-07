variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "keyvault_subnet_id" { type = string }
variable "keyvault_dns_zone_id" { type = string }
variable "db_admin_username" { type = string }
variable "db_fqdn" { type = string }
variable "redis_hostname" { type = string }
variable "vm_admin_username" { type = string }
variable "vm_ssh_public_key" { type = string }

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "redis_primary_access_key" {
  type      = string
  sensitive = true
}
