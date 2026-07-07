variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "vm_count" { type = number }
variable "vm_ids" { type = list(string) }
variable "vm_nic_ids" { type = list(string) }
variable "vm_vnet_id" { type = string }

variable "enable_dr_replication" {
  type        = bool
  description = "Enable Azure Site Recovery cross-region replication for the VMs. Backups (Recovery Services Vault + backup policy) are always created regardless of this flag."
  default     = true
}

variable "dr_location" {
  type        = string
  description = "Secondary Azure region VMs replicate to for disaster recovery. Must be a different region from the primary location."
}

variable "dr_address_space" {
  type        = string
  description = "Address space for the DR-region virtual network."
  default     = "10.1.0.0/16"
}

variable "dr_subnet_prefix" {
  type        = string
  description = "Subnet prefix inside the DR virtual network that replicated VMs attach to on failover."
  default     = "10.1.2.0/24"
}
