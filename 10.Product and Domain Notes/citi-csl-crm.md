## CITI → CSL → CRM — bridging securities to clients for tax/analytics

Source: `Confluence-space-export-205412.html/CITI-to-CSL-to-CRM-data-explained_2979889268.html`

### Why a bridge is required
- CITI (CitiImportFiles): securities/tax aggregates by ISIN; no client `AccID`.
- CRM: accounts and classifications by `AccID`; no ISIN.
- CSL transactions: the only layer that has both security (via `SecCode` mapped from ISIN) and client `AccID`.

### Correct join path
`CITI (ISIN)` → map to `SecCode` via Fusion → join `CSL.tblTransaction (SecCode, Exchange)` → produce `CSLTransactionsStaging (ISIN + AccID + amounts)` → join to `CRM (AccID)`.

### Procedure `spr_LoadTransactionsCSL` — key steps
1) Extract distinct ISINs per `@File_Type`, `@Fin_Year` from `CitiImportFiles` (CTE).
2) Build `#Fusion` by mapping ISIN → `SecCode`, `Exchange` from Fusion (`Issue`, `Asset`, `Exchange`).
3) Join `SQLCIP.CSL.dbo.tblTransaction` to `#Fusion` on `(SecCode, Exchange)` into `#CSL` with date/currency filters.
4) Insert into `dbo.CSLTransactionsStaging` with ISIN, security, transaction and client fields.

### Field provenance
- `GrossAmount` in `CSLTransactionsStaging` comes directly from `tblTransaction` (carried through `#CSL`).

### Modeling guidance
- Persist `CSLTransactionsStagingBackupSnapshot` for auditability; partition by year/date.
- Ensure collations/types match on `SecCode`, `Exchange` across systems; avoid implicit conversions.
- Build dimensional model: Security (by ISIN/SecCode), Account (AccID), and a fact over staged transactions.

