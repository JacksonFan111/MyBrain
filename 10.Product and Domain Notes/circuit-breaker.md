## Circuit Breaker — ChangedServiceLevels logic and productionization

Sources:
- `Confluence-space-export-205412.html/3.5-Circuit-Breaker---ChangedServiceLevels-Logics_3198156825.html`
- `Confluence-space-export-205412.html/Circuit-Breaker-notes_3198779447.html`

### Purpose
Detect accounts whose service level changed today and surface the associated holding value for monitoring and downstream actioning.

### Data lineage
- Sources: `Trading.F_FundsUnderManagement_v`, `Trading.dim_Account` (SCD2), optional `Trading.Dim_FixedInterestAsset`.
- CTEs:
  - `holdings`: latest holdings sum by `PortfolioServiceID`.
  - `PrevServiceLevel`: compute previous service level per `PortfolioServiceID` over effective dates (NZ time).
- Final select joins current `dim_Account` with both CTEs where `ServiceLevel <> PreviousServiceLevel`.

### Grain and caveats
- Grain: account‑current‑day; `HoldingValue` is at portfolio grain and repeats across accounts in the same portfolio.
- Risks: floating precision for money, per-row timezone conversion, SCD gaps with `LEAD()`, MAX(datekey) scan, implicit conversions on joins.

### Refactoring guidance (SQL sketch)
- Precompute `@TodayNZ date` once; cast money to DECIMAL(19,4); aggregate holdings at account grain; use `LAG()` + `ROW_NUMBER()` to identify prior/current rows; maintain small control table for latest date key.
- Indexes: `dim_Account(AccountKey, odsEffectiveFrom DESC, odsEffectiveTo DESC)`, FUM partitioned by `HoldingDateKey`.

### Operationalization
- Nightly orchestration in Synapse/ADF: truncate‑and‑reload or MERGE into a history table capturing every service-level hop with first holding snapshot on/after change date.
- Unit tests: assert 1 row per (AccountNumber, ChangeDate); spot checks per account.

