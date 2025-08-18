## FATCA/CRS — entity, joint, minor, and non-foreign holder handling

This document synthesizes handling guidance for entity account holders, joint/minor entities, and Step 7.6 non-foreign account-holder logic, tying into FATCA/CRS pivot outputs. Each section links to the exported HTML for details.

### Entities: account holder handling and mapping
Source: [Entity-account-holders-handling_2904129708.html](Confluence-space-export-205412.html/Entity-account-holders-handling_2904129708.html)

- Key sections for entity account holders (organizations):
  - Operation/Reporting (IDES 2.0: Operation = 'N', Reporting Jurisdiction = 'NZ', RecipientId = AccountID+PortfolioNo)
  - Reportable Account Type (pooled reporting):
    - '2' Passive NFFE with substantial U.S. owners (has TIN)
    - '3' Active NFFE or needs review (missing TIN)
  - Filer/Sponsored entity naming; Account Number details (PortfolioNo)
  - Portfolio service level (informational)
  - Account descriptions/status (e.g., closed flag by ClosureDate)
  - Account holder info/TINs: entity TIN or placeholders; jurisdiction code logic
  - Issued-by country code; personal fields remain blank for entities
  - Financial fields: Account Balance/Interest/Dividends/Gross Proceeds with zero-flooring; currency codes
  - Aggregated fields: typically blank unless applicable
  - Quality/placeholder patterns: `'NA'` for missing entity TINs; `'999999999'` for missing US individual TINs
- My learnings:
  - Distinguish entity vs individual paths early; for entities, SCPs/controlling persons must be derived and attached.
  - Use placeholders deliberately with logging to flag for remediation.

### Joint and minor entities — duplicates vs summaries
Source: [handling-Joint-and-Minor-entities_2931228679.html](Confluence-space-export-205412.html/handling-Joint-and-Minor-entities_2931228679.html)

- Why tricky:
  - Joint: multiple primary holders; each can be foreign/non-foreign.
  - Minor: guardian/authorized person may be the controlling person; minor may be the nominal account holder.
- Current logic alignment:
  - `#IndividualData` includes TradingEntityType in ('Individual','Joint','Minor Under 18 yrs') if foreign.
  - `#NonForeignAccHolderData` includes authorized roles even when not foreign on foreign-flagged entities.
- Strategy:
  - Keep multiple rows in “flat” reporting for completeness; or collapse to summaries with `ROW_NUMBER() OVER (PARTITION BY EntityID)` when needed for specific outputs.
- My learnings:
  - Preserve detail rows for compliance XML where multiple holders/controlling persons are valid; deduplicate for dashboards with window functions as needed.

### Step 7.6 — non-foreign individuals on foreign-flagged entities
Source: [Step-7.6-non-foreign-individuals-account-holder-handling_2933555202.html](Confluence-space-export-205412.html/Step-7.6-non-foreign-individuals-account-holder-handling_2933555202.html)

- Flow:
  1) Flag entities with at least one foreign/US-tax-resident individual (#EntitiesWithFlaggedIndividuals₂)
  2) Build non-foreign account-holders on those entities (`FATCA.NonForeignAccHolderData_jf`) restricted to natural-person entity types and authorized account-holder-like roles
  3) Merge into FATCA and CRS pivoted data, excluding name-equal matches to avoid duplicates
- Caveat:
  - Company/Trust entities excluded in this step; require separate logic for foreign controlling persons.
- My learnings:
  - Treat Step 7.6 as enrichment to ensure reporting completeness of non-foreign holders on reportable (foreign-triggered) entities.
  - Carefully collate comparisons (`COLLATE DATABASE_DEFAULT`) across sources to avoid false mismatches.

### Individuals with multiple roles
Source: [2912419930.html](Confluence-space-export-205412.html/2912419930.html)

- Purpose: unify logic where an Account has multiple Individuals with varied roles and tax residencies.
- Two target datasets:
  - `#IndividualData`: foreign individuals (beneficial owners or controlling/authorized persons with foreign TINs)
  - `#NonForeignAccHolderData`: non-foreign account holders on foreign-flagged entities
- Steps:
  - Count TINs per individual (`#TIN_Counts`) to mark single vs multiple TINs
  - Build `#IndividualData` and `#EntitiesWithFlaggedIndividuals` (foreign triggers)
  - Build `#NonForeignAccHolderData` filtered on roles, authorized, and absence of foreign TIN
  - Final union or separate outputs depending on target (flat vs XML sections)
- My learnings:
  - Model “reportable = f(role, residency)” with data quality filters (non-null TIN, exclude NZ TIN for foreign context).
  - Expect multiple rows per entity; deduplicate only when necessary for specific renderings.

### Practical patterns and guardrails
- Data quality:
  - Log missing TINs; standardize placeholder values; monitor multiple TIN scenarios for individuals.
- Performance:
  - Index key FKs and filter columns (e.g., roles/statuscode, TradingEntityType); push filters early; collate joins explicitly.
- Semantics:
  - Maintain explicit role lists for account-holder vs controlling-person semantics per regime (FATCA/CRS).
  - Separate flows for entities (Company/Trust) controlling persons; don’t assume natural-person flows cover all.

---

What I have learned overall (FATCA/CRS handling)
- Build both foreign individuals and non-foreign account-holders to fully represent reportable accounts.
- Joint/minor patterns yield multi-row outputs; use windowed selection for summaries but keep detail for compliance.
- Separate logic per entity type (natural person vs legal entities) and attach SCPs/controlling persons explicitly.
- Use consistent collation and placeholders; log and remediate data quality gaps early.

