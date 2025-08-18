## Power BI — deep-dive knowledge and learnings

This document consolidates technical guidance and lessons learned across the Power BI pages from the Confluence export. Each section links to the exported HTML for full details.

### Table calculations and contexts
Source: [Power-BI-Table-Calculations-and-Contexts_2881781780.html](Confluence-space-export-205412.html/Power-BI-Table-Calculations-and-Contexts_2881781780.html)

- Core concepts:
  - Row context vs filter context — measures manipulate filter context (CALCULATE), tables inherently have row context.
  - Totals often sum measure results, not recompute across full set; use HASONEVALUE/ISINSCOPE to branch logic.
- Patterns:
  - “Total of column ignoring certain filters” using ALL/REMOVEFILTERS.
  - Percentage-of-total via DIVIDE with a total measure in denominator.
- Pitfalls and fixes:
  - Incorrect grand totals: add CALCULATE(..., ALL(...)) to compute over intended scope.
  - Filters overwriting context: constrain with REMOVEFILTERS/ALLEXCEPT.
  - Divide-by-zero: always use DIVIDE.
- My learnings:
  - Always define explicit total semantics; don’t rely on visual totals.
  - Prefer REMOVEFILTERS/ALLEXCEPT over broad ALL when you need partial context retention.

### Measures as filters in Live Connection
Source: [Measures-as-Filters-in-Live-Connection-Mode-in-Power-BI_3112239155.html](Confluence-space-export-205412.html/Measures-as-Filters-in-Live-Connection-Mode-in-Power-BI_3112239155.html)

- Limitations in Live Connection:
  - Model is locked; no new tables/columns at report level.
  - Measures cannot be used as slicer fields (slicers need columns).
  - Measures can be used as visual-level filters only.
- Workarounds:
  - Ask model owner to add calculated column/flag to semantic model.
  - Use composite models (if available) to import a small helper table/flag.
  - Otherwise, stick to visual-level filtering.
- My learnings:
  - Requirement for slicers → design-time model change; don’t hack with report-only measures.
  - Document model governance boundaries early for report authors.

### Dynamic subscriptions (Per Recipient)
Source: [Power-BI-Dynamic-Subscriptions-Set-Up-Guide_3021504564.html](Confluence-space-export-205412.html/Power-BI-Dynamic-Subscriptions-Set-Up-Guide_3021504564.html)

- Capacity requirement: Premium/Fabric (or trial) workspace.
- Architecture:
  - Contact list dataset = “Data Set Triggers” (who gets emails + parameter values).
  - Main report dataset = “Main DataSets” (what the user sees; filtered via mapped parameters).
  - Current limit ≈ 1000 emails per run; only recipients/subject dynamic.
- Setup steps (condensed):
  1) Prepare contact list dataset and main dataset (Power Query M examples included in source).
  2) Publish PBIX to Premium/Fabric workspace; set report parameters/filters.
  3) Create Dynamic Per Recipient subscription; map contact list fields to recipients and report parameters.
  4) Choose attachment format; schedule or trigger; test to yourself first.
- My learnings:
  - Treat it like SSRS Data-Driven Subscriptions: separate “who” vs “what”.
  - Keep parameters aligned between contact list and report filters; validate at small scale first.

### Reconstruct AEOI Financials using DAX
Source: [Reconstruct-the-AEOI-Financials-lusing-DAX-in-Power-BI_2887745600.html](Confluence-space-export-205412.html/Reconstruct-the-AEOI-Financials-lusing-DAX-in-Power-BI_2887745600.html)

- Approach:
  - Translate SQL/SP logic to DAX measures (date-scoped aggregations, interest/tax split, Cashman vs non‑TD assets) and a calculated table using ADDCOLUMNS over summarized accounts.
  - Use TargetDate/TargetYear variables or parameters for time scoping.
  - Filter the output table to suppress rows with all-blank/zero metrics.
- Key measures (examples in source):
  - Holdings at MaxAvailableDate: TotalTDIncAI, TotalTDAI, Local variants; TotalHoldingSC/MPS/START; TotalHolding.
  - Transaction-year measures: TotalTDInterestPaid, TotalTDTaxPaid, TotalCMInterest, TotalCMTax, and gross sums.
- My learnings:
  - Centralize date logic to avoid drift between measures; consider What‑If parameters for user‑driven period selection.
  - Validate DAX output against SQL baselines iteratively; ensure relationships and granularity match.

### Composite model publish error — calculated columns vs measures
Source: [CIP-Risk-Dashboard-Mixed-Mode-Calculated-Column-Publish-Error_3161161737.html](Confluence-space-export-205412.html/CIP-Risk-Dashboard-Mixed-Mode-Calculated-Column-Publish-Error_3161161737.html)

- Symptom: Desktop OK, Service fails with “calculated column … does not hold any data … evaluation error” in composite model.
- Root cause:
  - Calculated columns evaluate at refresh in VertiPaq (Import engine); they cannot reference DirectQuery tables.
  - The column used SWITCH/FORMAT on DirectQuery sources → unsupported at refresh.
- Resolution:
  - Refactor calculated columns to measures (evaluated at query time) for logic that depends on DirectQuery.
  - Centralize formatting in a measure (e.g., “Formatted Metric Value”).
  - Keep Import-only calculated columns; keep DirectQuery logic in measures.
- Best practices:
  - Document table storage mode per table (Import vs DirectQuery) in the model.
  - Use ETL (SQL views/Power Query) for persistent logic if needed.
- My learnings:
  - In composite models, any cross‑mode logic should be measure‑based.
  - Avoid FORMAT in calculated columns that might evaluate during refresh.

### Known issue — colors change after publish to Service
Source: [14.-Known-Issues---Power-BI-colors-changing-when-reports-are-published-from-Power-BI-Desktop-to-the-web-service_2708832262.html](Confluence-space-export-205412.html/14.-Known-Issues---Power-BI-colors-changing-when-reports-are-published-from-Power-BI-Desktop-to-the-web-service_2708832262.html)

- Current state: Known Microsoft issue; guidance is mitigation rather than permanent fix.
- Mitigations:
  - Update Desktop to latest; clear cache; delete and republish.
  - Validate custom theme JSON; simplify if needed; avoid wildcards.
  - If using legend in stacked visuals, conditional color is not supported; set per‑legend color manually.
- My learnings:
  - Bake consistency checks into deployment (visual color parity Desktop vs Service).
  - Keep theme JSONs minimal and well‑formed; document unsupported combinations.

---

What I have learned overall (Power BI)
- Model mode dictates where logic can live: DirectQuery logic → measures; Import/persistent → calculated columns/ETL.
- Totals and context bugs are avoidable with explicit context control (ALL/REMOVEFILTERS/ALLEXCEPT) and branching for totals.
- Governance and automation (subscriptions, RLS) require upfront design of parameters, datasets, and access processes.
- Known product gaps (colors, slicers on measures in Live Connection) need documented workarounds and expectations.

