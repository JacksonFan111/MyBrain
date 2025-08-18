## ACE operations — schema audit and order scheduler process

Sources:
- `Confluence-space-export-205412.html/Ace-Schema-Audit-on-SQLUAT-and-SQLCIP_3084255305.html`
- `Confluence-space-export-205412.html/Overview-of-sp_GetACEOrders-Process_3086287042.html`

### UAT vs CIP schema audit (highlights)
- UAT-only objects to review/deprecate or deploy to CIP:
  - Tables: `ACE.BulkDailySent`, `ACE.BulkTrades_bak`, `ACE.IOSSchedulerW8TaxPoolAccSec`.
  - Views: `ACE.Currency`, `ACE.Currency_20170821`, `ACE.Security`.
  - Procs: `ACE.sp_UpsertBulkDailySent`, `ACE.sp_W8TaxPoolAccSecRefresh`.
- Procedure deltas to align:
  - `ACE.sp_GetACEOrders`: market list hints differ (`'OCTUS','NYSE'` vs `'NZSE'`); MERGE conditions include collation fixes and `ExpiryDate` logic.
  - `ACE.sp_MutualEqFundsRefresh`: CIP adds `i.assetCode = a.code` join guard.
  - `ACE.sp_W8TaxPoolRefresh`: linked server name diff (`[DynamicsProd]` vs `[Dynamics]`) but same backend; final SELECT commented in CIP.
- Constraint name differences are cosmetic; confirm functional parity.

Recommended actions:
- Decide target-of-truth for each delta; align code across envs; remove dev artifacts from UAT.
- For CRM links in W8 procs, standardize linked server alias via synonym or external data source.

### sp_GetACEOrders process — handover
Purpose: retrieve ACE source orders, MERGE into `ACE.IOSSchedulerOrders`, then output unprocessed orders for IRESS processing.

Flow:
1) Triggered by trade scheduler; params: `@FullRefresh bit`, `@Markets varchar`.
2) Build `cteOrders` joining securities, clients, tax pool info; derive custody, market, price/qty fields.
3) If `@FullRefresh=0`: MERGE into `ACE.IOSSchedulerOrders` (update/insert/delete based on diffs). If `1`: truncate/rebuild.
4) Final SELECT filters unprocessed orders by `@Markets` and advisor exclusions.

Ops notes:
- Keep MERGE comparisons collation‑safe (`COLLATE DATABASE_DEFAULT`).
- When markets diverge by env, parameterize via config table rather than code comments.
- Ensure indexes on `[Order No]`, `Status`, `Market`, and update paths to reduce lock times.
