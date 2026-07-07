# Disaster Recovery & Backup

This stack includes a Recovery Services Vault (`modules/recovery`) that always
backs up the application VMs, and — by default — replicates them to a
secondary region with Azure Site Recovery (ASR) for failover.

---

## What Gets Created

| Resource | Purpose | Always on? |
|---|---|---|
| `<prefix>-rsv` Recovery Services Vault | Holds backups and (if enabled) replication | Yes |
| VM backup policy | Daily backup, 30 daily / 12 weekly / 12 monthly retention | Yes |
| `azurerm_backup_protected_vm` | Registers each app VM against the policy | Yes |
| `<prefix>-dr-rg` / `<prefix>-dr-vnet` | Secondary-region resource group + network | Only if `enable_dr_replication = true` |
| ASR replication policy, fabrics, containers, network mapping | Azure Site Recovery plumbing | Only if `enable_dr_replication = true` |
| `azurerm_site_recovery_replicated_vm` per VM | Continuous VM replication to the DR region | Only if `enable_dr_replication = true` |

Toggle replication off for lower-cost or non-prod deployments:

```hcl
enable_dr_replication = false   # backups still run; no cross-region replica
```

When enabled, pick a secondary region with `dr_location` (default `westus`,
pairs with the default `eastus` primary — pick a real [Azure paired region](https://learn.microsoft.com/azure/reliability/cross-region-replication-azure)
if you change `location`).

---

## Known Provider Quirk: First Apply May Need a Re-run

Azure Site Recovery resources in the `azurerm` provider are order-sensitive —
the Recovery Services Vault needs a few minutes to register the Site Recovery
resource provider before the fabric/container/mapping resources can be
created. If `terraform apply` errors out on any `azurerm_site_recovery_*`
resource on the **first** run, simply run `terraform apply` again. This is a
known ASR/Terraform limitation, not a configuration problem — subsequent
applies pick up where the first one left off.

---

## Restoring a VM From Backup

```bash
# List available recovery points
az backup recoverypoint list \
  --resource-group <customer>-<env>-rg \
  --vault-name <customer>-<env>-rsv \
  --container-name "iaasvmcontainer;iaasvmcontainer;<customer>-<env>-rg;<customer>-<env>-vm1" \
  --item-name "vm;iaasvmcontainer;iaasvmcontainer;<customer>-<env>-rg;<customer>-<env>-vm1"

# Restore to a new VM (do not restore over the original — Terraform manages it)
az backup restore restore-disks \
  --resource-group <customer>-<env>-rg \
  --vault-name <customer>-<env>-rsv \
  --container-name <container-name> \
  --item-name <item-name> \
  --rp-name <recovery-point-name> \
  --storage-account <staging-storage-account>
```

---

## Failing Over to the DR Region

Only applies when `enable_dr_replication = true`.

```bash
# 1. Check replication health first
az site-recovery replication-protected-item show \
  --resource-group <customer>-<env>-rg \
  --vault-name <customer>-<env>-rsv \
  --fabric-name <customer>-<env>-fabric-source \
  --protection-container-name <customer>-<env>-protcont-source \
  --name <customer>-<env>-vm1-replication

# 2. Trigger a planned failover (or "Unplanned" if the primary region is down)
az site-recovery recovery-plan test-failover \
  --resource-group <customer>-<env>-rg \
  --vault-name <customer>-<env>-rsv \
  --name <recovery-plan-name> \
  --direction PrimaryToRecovery
```

After failover, the VM runs in `<customer>-<env>-dr-rg` / `<customer>-<env>-dr-vnet`
in `dr_location`. Point your DNS/CDN origin at the failed-over VM (or a new
Application Gateway you stand up in the DR region — this template does not
auto-provision one, since AGW is stateless and cheap to recreate on demand).

To fail back, re-run replication in the reverse direction once the primary
region is healthy again, following the same `az site-recovery` commands with
`--direction RecoveryToPrimary`.

---

## Removing the CanNotDelete Lock Before Destroy

Both the primary and (if DR is enabled) the secondary resource group are
covered by the `azurerm_management_lock` on the primary RG only — the DR
resource group has no lock, since it's fully owned by the `recovery` module
and torn down along with everything else on `terraform destroy`.
