variable "name_prefix"         { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "tags"                { type = map(string) }
variable "db_sku"              { type = string }
variable "db_storage_mb"       { type = number }
variable "db_admin_username"   { type = string }
variable "delegated_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "redis_capacity"      { type = number }
variable "redis_family"        { type = string }
variable "redis_sku"           { type = string }
variable "redis_subnet_id"     { type = string }
variable "redis_dns_zone_id"   { type = string }

variable "db_admin_password" {
  type      = string
  sensitive = true
}
