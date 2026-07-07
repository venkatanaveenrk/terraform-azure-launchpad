# Cost Estimates — E-commerce Vertical

> East US pricing, July 2026. Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for exact quotes.

Every tier now includes a Key Vault, a Recovery Services Vault with daily VM
backups, and (by default) Azure Site Recovery cross-region replication. Set
`enable_dr_replication = false` in `terraform.tfvars` to drop the Site Recovery
line and its replica-region storage cost — see [docs/disaster-recovery.md](disaster-recovery.md).

## Small — ~$440/month (~$400/month without DR replication)

Best for: Startups, MVPs, <10,000 monthly active users

| Resource | SKU | Est. Monthly |
|---|---|---|
| Linux VM × 1 | Standard_B2s_v2 | $30 |
| Application Gateway WAF v2 | 2 capacity units (min., no zone redundancy) | $250 |
| PostgreSQL 16 Flexible Server | B_Standard_B2s, 32GB, Zone HA | $60 |
| Redis Cache | C0 Basic | $16 |
| Storage (OS disk + boot diag) | Premium SSD 64GB | $12 |
| Private DNS + networking | — | $5 |
| Key Vault | Standard, 1 private endpoint | $10 |
| Recovery Services Vault + VM Backup | 1 protected instance | $15 |
| Site Recovery replication | 1 VM, cross-region (optional) | $40 |
| **Estimated total** | | **~$438/mo** |

Note: the Application Gateway now runs a minimum of 2 autoscale instances
instead of spreading 1 instance across 3 zones — this is the change that
increased the AGW line item vs. earlier versions of this template, in exchange
for dropping the zone-redundancy dependency. See [README.md](../README.md#architecture--e-commerce).

---

## Medium — ~$1,020/month (~$940/month without DR replication)

Best for: Growing businesses, 10k–100k monthly active users

| Resource | SKU | Est. Monthly |
|---|---|---|
| Linux VM × 2 | Standard_D4s_v5 | $280 |
| Application Gateway WAF v2 | 2 capacity units | $250 |
| PostgreSQL 16 Flexible Server | GP_Standard_D4s_v5, 128GB, Zone HA | $290 |
| Redis Cache | C1 Standard | $55 |
| Storage (OS disks × 2) | Premium SSD 64GB each | $25 |
| Key Vault | Standard, 1 private endpoint | $10 |
| Recovery Services Vault + VM Backup | 2 protected instances | $30 |
| Site Recovery replication | 2 VMs, cross-region (optional) | $77 |
| **Estimated total** | | **~$1,017/mo** |

---

## Large — ~$2,310/month (~$2,195/month without DR replication)

Best for: Enterprise, high-traffic stores, <1M monthly active users

| Resource | SKU | Est. Monthly |
|---|---|---|
| Linux VM × 3 | Standard_E8s_v5 | $840 |
| Application Gateway WAF v2 | 3 capacity units | $375 |
| PostgreSQL 16 Flexible Server | GP_Standard_D8s_v5, 512GB, Zone HA | $780 |
| Redis Cache | C2 Standard | $110 |
| Storage (OS disks × 3) | Premium SSD 64GB each | $37 |
| Key Vault | Standard, 1 private endpoint | $10 |
| Recovery Services Vault + VM Backup | 3 protected instances | $45 |
| Site Recovery replication | 3 VMs, cross-region (optional) | $114 |
| **Estimated total** | | **~$2,311/mo** |

---

## What Drives the Recovery/DR Costs

- **VM Backup** (~$10–15/VM/month): Azure Backup per-protected-instance fee + backup storage (35-day retention, GRS).
- **Site Recovery replication** (~$25–40/VM/month, optional): ASR per-protected-instance license fee + replica managed disks sitting idle in the DR region + a small staging storage account + cross-region data transfer (scales with how much data each VM's disk churns through).
- Disable it for dev/staging or cost-sensitive small deployments with `enable_dr_replication = false` — backups still run either way.

## Cost Saving Tips

- **Reserved Instances**: Commit to 1-year for VMs and DB — save 30–40%
- **Auto-shutdown**: Set on dev/staging environments (not prod)
- **Storage autogrow**: Enable on PostgreSQL to avoid over-provisioning
- **Azure Cost Alerts**: Set budget alerts at 80% and 100% of expected spend
- **Right-size**: Start small, upgrade size when metrics show sustained >70% CPU
- **Skip Site Recovery on non-prod**: `enable_dr_replication = false` removes the largest optional line item
