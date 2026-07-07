# Cost Estimates — E-commerce Vertical

> East US pricing, July 2026. Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for exact quotes.

## Small — ~$250/month

Best for: Startups, MVPs, <10,000 monthly active users

| Resource | SKU | Est. Monthly |
|---|---|---|
| Linux VM × 1 | Standard_B2s_v2 | $30 |
| Application Gateway WAF v2 | 1 capacity unit | $125 |
| PostgreSQL 16 Flexible Server | B_Standard_B2s, 32GB, Zone HA | $60 |
| Redis Cache | C0 Basic | $16 |
| Storage (OS disk + boot diag) | Premium SSD 64GB | $12 |
| Private DNS + networking | — | $5 |
| **Estimated total** | | **~$248/mo** |

Note: WAF v2 has a fixed cost regardless of traffic. This dominates at small scale.

---

## Medium — ~$980/month

Best for: Growing businesses, 10k–100k monthly active users

| Resource | SKU | Est. Monthly |
|---|---|---|
| Linux VM × 2 | Standard_D4s_v5 | $280 |
| Application Gateway WAF v2 | 2 capacity units | $250 |
| PostgreSQL 16 Flexible Server | GP_Standard_D4s_v5, 128GB, Zone HA | $290 |
| Redis Cache | C1 Standard | $55 |
| Storage (OS disks × 2) | Premium SSD 64GB each | $25 |
| **Estimated total** | | **~$900/mo** |

---

## Large — ~$2,150/month

Best for: Enterprise, high-traffic stores, <1M monthly active users

| Resource | SKU | Est. Monthly |
|---|---|---|
| Linux VM × 3 | Standard_E8s_v5 | $840 |
| Application Gateway WAF v2 | 3 capacity units | $375 |
| PostgreSQL 16 Flexible Server | GP_Standard_D8s_v5, 512GB, Zone HA | $780 |
| Redis Cache | C2 Standard | $110 |
| Storage (OS disks × 3) | Premium SSD 64GB each | $37 |
| **Estimated total** | | **~$2,142/mo** |

---

## Cost Saving Tips

- **Reserved Instances**: Commit to 1-year for VMs and DB — save 30–40%
- **Auto-shutdown**: Set on dev/staging environments (not prod)
- **Storage autogrow**: Enable on PostgreSQL to avoid over-provisioning
- **Azure Cost Alerts**: Set budget alerts at 80% and 100% of expected spend
- **Right-size**: Start small, upgrade size when metrics show sustained >70% CPU
