## CRM auditing and adviser domain — deep-dive knowledge and learnings

This document consolidates CRM audit decoding, audit engine internals, runtime pipelines, and the adviser domain model. Each section links to the exported HTML for source details.

### CRM Audit Decoder — design and runnable SQL
Sources:
- [CRM-Change-Data-Audit-design_3203367004.html](Confluence-space-export-205412.html/CRM-Change-Data-Audit-design_3203367004.html)
- [CRM-Audit-Master-Tech-Notes_3204120591.html](Confluence-space-export-205412.html/CRM-Audit-Master-Tech-Notes_3204120591.html)

- Problem: Dynamics stores audit data as “old-value snapshots” per save, with two key fields per row: `AttributeMask` (list of changed column numbers) and `ChangeData` (tilde `~` list of old values; positionally aligned to the mask). New values live in base tables.
- Script approach (decoder):
  - Discover entity metadata (`dbo.Entity`, `dbo.Attribute`, `dbo.LocalizedLabelView`) to map column numbers → logical names, display names, data types, and option-set info.
  - Pull audit rows from `dbo.Audit` by ObjectTypeCode and time window.
  - Split `AttributeMask` into rows (#Mask), split `ChangeData` into rows (#Vals), align by ordinal into (#Pairs), filter to target attributes (#Changes).
  - Type attempts: parse `OldValueRaw` into GUID, INT, DECIMAL, DATETIME where possible, preserving raw text.
  - Build context per AuditId (list of “other fields changed in the same event”).
  - Optionally fetch current values from a base view/table (e.g., `dbo.Account`) via dynamic projection; resolve `…adviserid` lookups to `SystemUser.FullName`.
  - Output one row per changed attribute per event with old value, current value, who changed it, when, and other-changed‑fields summary.
- Notes and gotchas handled:
  - Positional alignment is critical: `AttributeMask` order matches `ChangeData` chunks; avoid string matching by name.
  - Handles `"table,GUID"` lookup oddities by splitting and normalizing GUID for later name resolution.
  - Option-set value translation via `StringMap`; datetime UTC→local conversion by `fn_UTCToLocalTime_rpt`.
- My learnings:
  - Treat audit decoding as a deterministic pipeline: filter → sanitize → explode → enrich (metadata) → translate (options/lookups) → convert time → pair Old/New.
  - Use temp tables and set-based operations; avoid cursors. Use window functions (`LEAD`) to pair changes.
  - Keep dynamic projection minimal and safe; rely on metadata to select only valid attribute columns.

### Audit engine internals, math model, and pedagogy
Source: [CRM-Audit-Master-Tech-Notes_3204120591.html](Confluence-space-export-205412.html/CRM-Audit-Master-Tech-Notes_3204120591.html)

- What the platform does on Save:
  - Checks global, entity, and attribute audit flags; if enabled, serializes changed columns into `AttributeMask` (comma list) and `ChangeData` (tilde list of old values) in the same order; writes metadata (Action, ObjectTypeCode, ObjectId, User, CreatedOn UTC).
  - Many-to-one: a single Save may produce 0/1/N audit rows depending on event types (Update, State change, N:N associate/disassociate, Delete).
- Action code cheat-sheet and edge cases: Create, Update, Delete, Activate/Deactivate, Assign, Associate/Disassociate.
- Formalization:
  - Defines audit row tuple r = (action, OTC, GUID, C, D, t, u) with positional invariant between C (mask) and D (old values).
  - Functions for enrichment and transformation: column metadata ϕ, option label σopt, lookup resolution λ, time converter τ.
  - Pipeline F = f7 ∘ f6 ∘ f5 ∘ f4 ∘ f3 ∘ f2 ∘ f1 from raw rows to normalized report rows; event-stream graph view for change histories; pattern-mining prompts (anomalies, hot columns, convergences).
- My learnings:
  - Understanding capture rules (why only old values, partitioning by quarter) clarifies why the decoder must fetch current values and resolve lookups.
  - The formal model enables unit tests and potential ML over audit streams (e.g., user-change profiles, anomaly detection).

### Runtime pipeline diagrams and WHERE filters
Source: [CRM-AUDIT-Logics_3299410033.html](Confluence-space-export-205412.html/CRM-AUDIT-Logics_3299410033.html)

- Data-flow (from params → targets → audit scan → split/align → enrich with current values, options, lookup names → rollup → entity name resolution → PS-context enrichment → final SELECT with LIKE filters).
- Sequence and ER-style temp object diagrams show the intermediate artifacts (#E, #Mask, #Vals, #Changes, #Current, #OptOld/#OptCur, #RefNamesOld/#RefNamesCur, #AuditRollup, #PS_Context).
- Where filters apply: `PortfolioIdLike`, `PSLevelLike`, `AdvisorLike`, `NameLike`, `FieldLogicalNameLike` — at PS context and final output.
- My learnings:
  - Keep PS context enrichment modular to support downstream filters; centralize name resolution and option-set translation to avoid duplication.

### Adviser domain model and canonical joins
Source: [CRM---Adviser-domain-tables_2947514382.html](Confluence-space-export-205412.html/CRM---Adviser-domain-tables_2947514382.html)

- Conceptual model:
  - `BusinessUnit (bu)` ↔ `dsl_advisercommissioncode (acc)` ↔ `dsl_advisercommissionlink (acl)` ↔ `SystemUser (su)`; Teams (`TeamBase`, `TeamMembership`) group users; advisers may be inferred from teams with flags (e.g., `t.dsl_IsFromAdvisorCode = 1`).
- Canonical queries:
  - Flatten adviser record: `acc` + `acl` + `su` + `bu` to return AdviserID, AdvisorName, Email, BranchName/Code.
  - Active advisers: `acc.dsl_Retired = 0 AND acl.statecode = 0 AND acc.dsl_name <> 'HEADOFFICE'`.
  - Team-based adviser lookup for DA user type; select from `TeamBase/TeamMembership/SystemUserBase` and `BusinessUnitBase` with `StringMap` on `dsl_usertype`.
- My learnings:
  - Normalize branch codes and ensure joins follow FK intent (commission code → link → user, and branch via `acc.dsl_BranchId`).
  - When deriving access/security, use team flags plus `IsDisabled` and state codes to avoid stale memberships.

### Implementation notes and best practices
- Collation and case: Cross-server joins and Linked Servers might require `COLLATE DATABASE_DEFAULT` and careful casing; prefer deterministic casing of GUIDs.
- Indexing: Add nonclustered indexes on `Audit(ObjectTypeCode, CreatedOn)`, and temp table surrogate keys when processing large windows; index `StringMap` by `(AttributeName, AttributeValue)`.
- Packaging: Wrap the decoder as `usp_AuditDecode` with parameters (`@EntityLogicalName`, `@AttributeExactLogicalName`/`@AttributeNameLike`, `@MonthsBack`, `@BaseObjectName`, `@LanguageId`).
- Testing: Unit-test on known audit rows (single/multi-field updates, lookup changes) and verify positional alignment and option/lookup translation.

---

What I have learned overall (CRM/audit)
- Dynamics audit is positionally encoded; decoding must be mask → values by ordinal, then enrich.
- A clean, stepwise pipeline and temp-table design enables reliable, performant normalization without cursors.
- Adviser domain joins traverse commission code/link/user and team membership; keep branch alignment and state filters consistent.
- Formalizing the pipeline supports testing, performance tuning, and future analytics.

