## ALOHA RDS data domains — catalog and historical tables

Source: `Confluence-space-export-205412.html/ALOHA-RDS-Exploration_3016327726.html`

### Collections overview
- Reference: `RefContact`, `RefAccount`, `RefSecurity`, `RefBroker`, `RefCustodian`, `RefIssuer`, etc.
- Transactional/valuation: `ThvdsTransaction`, `ThvdsValuation`, `ThvInvestmentIncome`.
- Performance: `PerfBenchmark`, `PerfMarketIndex`, `PerfMarketIndexValue`.
- Fees: `FeeInvoice`, `FeeSchedule`.
- Payments: `PmtOrder`, `PmtPlacement`.

Counts and descriptions are captured in the source page to act as a data dictionary index.

### Hist tables and dbt staging
- Fee domain: `adsFeeInvoiceHist_*`, `adsFeeScheduleHist_*` with detail/tiers/GST sub-entities; `__dbt_tmp` indicates transient staging during transforms.
- Performance domain: `adsPerfBenchmarkHist*`, `adsPerfMarketIndex*` with definitions, components, hierarchies, values.
- Payment domain: `adsPmtOrderHist*`, `adsPmtPlacementHist*`, message text.
- Reference domain: `adsRefAccountHist*` including alternate identifiers, available cash balances, contacts, tax details.
- Transaction/valuation: `adsThvTransactionTypeHist*`, `adsThvInvestmentIncomeHist*` and detail children.

### Key takeaways
- `Hist` suffix = point-in-time snapshots suitable for audits and slow changes.
- `__dbt_tmp` suffix = dbt intermediate tables; not for direct consumption; expect cleanup post-success.
- Domain grouping clarifies ownership and expected join patterns back to live collections.

### Operational guidance
- Partition large hist tables by date keys where applicable; index on business keys used for merges.
- Publish consumer views that hide `__dbt_tmp` and expose curated hist timelines.
- Enforce naming and DDL consistency (types/collations) between live and hist variants to enable set-based merges.

