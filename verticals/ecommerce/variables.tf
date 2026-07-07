# =============================================================================
#  azure-infra-quickstart — ecommerce vertical
#  Fill terraform.tfvars (copy from terraform.tfvars.example) and run:
#    terraform init && terraform apply
# =============================================================================

variable "customer" {
  type        = string
  description = "Customer / brand name. All resources will be named <customer>-<resource>. e.g. 'adidas' → adidas-rg, adidas-vm, adidas-vnet"
  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.customer))
    error_message = "customer must be 2-20 lowercase letters, numbers, or hyphens. e.g. 'adidas', 'my-shop'"
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Appended to resource names: adidas-prod-vm, adidas-dev-vm"
  default     = "prod"
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be prod, staging, or dev."
  }
}

variable "location" {
  type        = string
  description = "Primary Azure region for all resources."
  default     = "eastus"
}

variable "domain_name" {
  type        = string
  description = "Your domain e.g. adidas.com — point your DNS/CDN provider's origin at the AGW public IP and terminate SSL there."
}

variable "size" {
  type        = string
  description = "Infrastructure size tier. Controls VM SKU, DB SKU, Redis tier, AGW capacity."
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "size must be small, medium, or large. See docs/cost-estimates.md."
  }
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for Linux VMs. e.g. 'azureuser'"
  default     = "azureuser"
}

variable "vm_ssh_public_key" {
  type        = string
  description = "Your SSH public key content for VM access. Run: cat ~/.ssh/id_rsa.pub"
}

variable "db_admin_username" {
  type        = string
  description = "PostgreSQL administrator login name."
  default     = "psqladmin"
}

variable "db_admin_password" {
  type        = string
  description = "PostgreSQL administrator password. Min 8 chars, must include uppercase, lowercase, number, special char."
  sensitive   = true
  validation {
    condition     = length(var.db_admin_password) >= 8 && can(regex("[A-Z]", var.db_admin_password)) && can(regex("[a-z]", var.db_admin_password)) && can(regex("[0-9]", var.db_admin_password)) && can(regex("[^A-Za-z0-9]", var.db_admin_password))
    error_message = "db_admin_password must be at least 8 characters and include an uppercase letter, lowercase letter, number, and special character."
  }
}

variable "enable_dr_replication" {
  type        = bool
  description = "Enable Azure Site Recovery cross-region VM replication for disaster recovery, on top of the always-on backups. Adds a second region's VNet, a staging storage account, and ongoing per-VM replication cost — disable for lower-cost/non-prod deployments."
  default     = true
}

variable "dr_location" {
  type        = string
  description = "Secondary Azure region VMs replicate to for disaster recovery (only used when enable_dr_replication is true). Must differ from location — see docs/disaster-recovery.md for supported region pairs."
  default     = "westus"
}

# =============================================================================
#  Size presets — do not edit unless you know what you're doing
# =============================================================================
locals {
  size_map = {
    small = {
      vm_sku         = "Standard_B2s_v2"
      vm_count       = 1
      db_sku         = "B_Standard_B2s"
      db_storage_mb  = 32768
      redis_capacity = 0
      redis_family   = "C"
      redis_sku      = "Basic"
      agw_capacity   = 2
    }
    medium = {
      vm_sku         = "Standard_D4s_v5"
      vm_count       = 2
      db_sku         = "GP_Standard_D4s_v5"
      db_storage_mb  = 131072
      redis_capacity = 1
      redis_family   = "C"
      redis_sku      = "Standard"
      agw_capacity   = 2
    }
    large = {
      vm_sku         = "Standard_E8s_v5"
      vm_count       = 3
      db_sku         = "GP_Standard_D8s_v5"
      db_storage_mb  = 524288
      redis_capacity = 2
      redis_family   = "C"
      redis_sku      = "Standard"
      agw_capacity   = 3
    }
  }

  sz          = local.size_map[var.size]
  name_prefix = "${var.customer}-${var.environment}"

  common_tags = {
    Customer    = var.customer
    Environment = var.environment
    ManagedBy   = "Terraform"
    Vertical    = "ecommerce"
    Repository  = "azure-infra-quickstart"
  }
}
