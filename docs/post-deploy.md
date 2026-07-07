# Post-Deploy Guide

After `terraform apply` completes, follow these steps in order.

---

## Step 1 — Review Outputs

```bash
terraform output                         # see all outputs
terraform output app_gateway_public_ip   # the IP your DNS/CDN origin points to
```

---

## Step 2 — Configure DNS + SSL

The Application Gateway serves plain HTTP only — SSL/TLS is terminated at your DNS/CDN provider (Cloudflare, Azure Front Door, etc.), which then forwards HTTP to the Application Gateway as its origin.

At your DNS/CDN provider:

```
Type:  A (or CNAME, per your provider)
Name:  @   (root domain, or 'www' if subdomain)
Value: <app_gateway_public_ip from terraform output>
```

Enable SSL/TLS termination ("Flexible" mode on Cloudflare, or equivalent) so the provider handles the HTTPS certificate — you do not need to manage a certificate on the Application Gateway itself.

Verify propagation:
```bash
nslookup yourdomain.com
dig yourdomain.com A
```

---

## Step 3 — Set Up VM Access

VMs have no public IP. Choose your access method:

### Option A — Temporary IP Allow (quickest for solo devs)
Add your IP to the VM NSG in `modules/networking/main.tf`:
```hcl
security_rule {
  name                       = "AllowSSHFromMyIP"
  priority                   = 200
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "YOUR.IP.ADDRESS/32"
  destination_address_prefix = "*"
}
```
Then `terraform apply`. Remove when done.

### Option B — Azure Bastion (browser-based, no client needed)
Add to `modules/networking/main.tf`:
```hcl
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.5.0/26"]
}
```
Add to `modules/compute/main.tf`:
```hcl
resource "azurerm_public_ip" "bastion" {
  name                = "${var.name_prefix}-pip-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "main" {
  name                = "${var.name_prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  ip_configuration {
    name                 = "bastion-ip"
    subnet_id            = <bastion_subnet_id>
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
```

### Option C — VPN Gateway (recommended for teams)
See [Azure VPN Gateway docs](https://learn.microsoft.com/en-us/azure/vpn-gateway/).

---

## Step 4 — Connect to VMs and Deploy Your App

```bash
# SSH using the key matching your vm_ssh_public_key
ssh -i ~/.ssh/id_rsa azureuser@<vm_private_ip>

# On the VM — install your app runtime
# Node.js example:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash
sudo apt install nodejs

# Clone and run your app
git clone https://github.com/yourorg/your-app.git /var/www/app
cd /var/www/app && npm install && npm run build
pm2 start npm -- start
pm2 startup && pm2 save
```

Your app should listen on `127.0.0.1:3000` — nginx on each VM proxies `/` there and serves `/health` for the Application Gateway's health probe.

---

## Step 5 — Fetch App Secrets From Key Vault

DB credentials, the DB connection string, Redis hostname/key, and the VM
admin username/SSH public key are all stored as secrets in the deployment's
Key Vault (`modules/keyvault`) — nothing sensitive needs to live in your CI/CD
pipeline or a `.env` file checked into git.

```bash
KV_NAME=$(terraform output -raw key_vault_name 2>/dev/null || az keyvault list --resource-group <customer>-<env>-rg --query "[0].name" -o tsv)

# Grant yourself access first if you weren't the one who ran terraform apply:
# az role assignment create --role "Key Vault Secrets User" \
#   --assignee <your-object-id> --scope $(az keyvault show --name $KV_NAME --query id -o tsv)

az keyvault secret show --vault-name $KV_NAME --name db-connection-string --query value -o tsv
az keyvault secret show --vault-name $KV_NAME --name redis-primary-access-key --query value -o tsv
az keyvault secret show --vault-name $KV_NAME --name redis-hostname --query value -o tsv
```

The Key Vault sits behind a private endpoint (no public network access) — run
the commands above from a machine inside the VNet (a VM, VPN client, or
Azure Bastion session), or temporarily use Azure Cloud Shell with a VNet
integration if you need access from outside.

Secrets stored: `db-admin-username`, `db-admin-password`, `db-connection-string`,
`redis-hostname`, `redis-primary-access-key`, `vm-admin-username`, `vm-ssh-public-key`.

Note: only the SSH **public** key is stored — Terraform never has access to
your private key, so it can't be escrowed here. Keep your private key backed
up separately (e.g. in your own password manager).

---

## Destroy Infrastructure

```bash
# Remove CanNotDelete lock first
az lock delete \
  --name <customer>-<env>-lock \
  --resource-group <customer>-<env>-rg

# Destroy all resources
terraform destroy
```
