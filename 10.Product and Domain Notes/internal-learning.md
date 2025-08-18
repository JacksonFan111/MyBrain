## Internal learning — deep-dive knowledge and learnings

This document synthesizes detailed context from the “Internal” topic in the Confluence export and captures key learnings and operational nuances. Each section links to the original exported HTML.

### 00. Confluence Technical Documents Writing Framework
Source: [00.-Confluence-Technical-Documents-Writing-Framework_2555183180.html](Confluence-space-export-205412.html/00.-Confluence-Technical-Documents-Writing-Framework_2555183180.html)

- Purpose: Provide a structured approach for documenting CIP Data Architecture technical content with clarity, completeness, and maintainability.
- Structure highlights:
  - Instructions for documenting processes: gather info → outline → write clearly → visuals → review → feedback → publish/maintain.
  - Learning framework sections: introduction, high‑level and detailed architecture, data flows, processes (ingestion, transformation, storage, access, security), implementation guide, best practices, troubleshooting, case studies, appendices.
- Key learnings I will apply:
  - Always include: objective, context diagrams, component breakdowns, and data flow views.
  - Treat troubleshooting as first‑class; document error patterns and resolutions.
  - Maintain a glossary and references to reduce ambiguity.

### 01. CIP Data Learning from Chris Church
Source: [01.-CIP-Data-Learning-From-Chris-Church_2555641857.html](Confluence-space-export-205412.html/01.-CIP-Data-Learning-From-Chris-Church_2555641857.html)

- Current state (high level):
  - Inputs: client data (names/addresses), transactional data (orders/contracts), market/asset data (assets/prices).
  - Data path: on‑prem SQL DBs (operational and Dynamics CRM) → Data Lake → Azure Synapse (pipelines + notebooks on spark pools) → Data Warehouse → on‑prem SSAS Tabular (~54 GB) → BI interfaces (Power BI, Client Portal, SSRS/Insights).
- Source systems to remember:
  - Chelmer Suite: ACE, Fusion (asset and transactional), Cashman.
  - NZXWT SQL DB (transactional extracts).
  - Dynamics CRM (entity stores; primary client/account/role system) and SharePoint library (unstructured).
- Concept: Holdings are cumulative portfolio aggregations (sum of trade movements over time), not point-in-time snapshots only.
- Client service ERD hierarchy (simplified): Contacts → Roles → Accounts/Trading Entities (six‑digit key) → Portfolios.
- Future state: SS&C ALOHA migration
  - SS&C side uses MongoDB → sinks to ADS (Aloha Data Store) → replicated into RADS (R‑ALOHA Data Store) → managed Azure DB.
  - Anticipated need for more API‑based real‑time integration patterns.
- My learnings:
  - Expect significant integration and semantic mapping work during Chelmer/CRM to ALOHA transitions.
  - The SSAS model is a performance/semantic hub; changes ripple to Insights and Power BI—treat with care.
  - Plan RLS/security early when shifting models to new stores.

### 02. Learning how Power BI is governed in CIP
Source: [02.-Learning-how-PBI-are-Governed-in-CIP_2556100609.html](Confluence-space-export-205412.html/02.-Learning-how-PBI-are-Governed-in-CIP_2556100609.html)

- Principle: Access requests must go through Service Portal—no ad‑hoc grants by business admins.
- Security layers:
  - Workspaces (workspace roles), Apps (distribution), RLS (tabular security model), Tenant settings.
  - RLS: critical for branch/adviser scoping (Area Managers, PWAs, Associates, etc.).
- Preferred data sources: CIP Tabular Model via gateway; direct SQL where appropriate.
- My learnings:
  - Treat RLS as policy: defined centrally in ReferenceBI and propagated; avoid bespoke per‑report RLS logic.
  - Governance living doc exists; align report development and access workflows to it end‑to‑end.

### 03. Learning how SSRS is governed in CIP
Source: [03.-Learning-How-SSRS-is-governed-in-CIP_2556559427.html](Confluence-space-export-205412.html/03.-Learning-How-SSRS-is-governed-in-CIP_2556559427.html)

- Landscape: ~750 SSRS (Insights) reports; usage and governance visible via Power BI “Insights Catalogue” and “Insights SSRS Monitoring”.
- Request types:
  - Interactive (Request Type 0): on‑demand, user‑driven render.
  - Subscription (Request Type 1): scheduled delivery; standard vs data‑driven subscriptions.
- Change management workflow (high level):
  - Git/Bitbucket repo `Craigs.Insights.ReportPortal`; feature branch → change in VS/Report Builder → commit/push → PR → reviewer from Data Team → merge.
- My learnings:
  - Centralize SSRS source control; no direct server‑side edits.
  - Monitor report execution mix (interactive vs subscription) to prioritize performance work.

### 04. Learning KAPSQLDAT (new) — successor to DataServices (old dumping ground)
Source: [2555838664.html](Confluence-space-export-205412.html/2555838664.html)

- Context: KAPSQLDAT‑XX server family set up in 2022 to host non‑application data workloads previously on `SQLCIP\DataServices`.
- Key databases and purposes:
  - Integration: staging/in‑transit data for calculations/processes.
  - NZXWT: drops used for Data Warehouse ingestion (no direct BI connection to NZXWT).
  - ReferenceBI: mappings to combine transactional systems + BI security model (RLS builder inputs).
  - SSISDB: SSIS catalog.
  - StagingBI: staging for Data Warehouse.
  - Vault: history‑keeping store (e.g., IRD reporting, Funds Flow).
- Operational specifics:
  - Actual old server name: `SVSQLCIP\SQLCIP`; DB: `DataServices`.
  - Linked server caveats: case sensitivity; cross‑server joins may need `COLLATE database_default` to handle collation mismatches.
  - “KAP” refers to data center location (Kapua).
- My learnings:
  - Normalize collations early when bridging legacy servers to avoid subtle join errors.
  - Put security mappings and RLS state into a reference DB and sync to models daily.

### 06. Learning CIP Data Delivery process
Source: [06.-Learning-CIP-Data-Delivery-process_2568683521.html](Confluence-space-export-205412.html/06.-Learning-CIP-Data-Delivery-process_2568683521.html)

- Git process (bitbucket + SourceTree): analysis → feature branch → develop/test/commit → push/PR → feedback → merge → release.
- Work taxonomy:
  1) Dashboard/Report Dev, 2) Ad‑hoc data pulls (often SP‑driven), 3) BI enhancements (new sources/columns/semantic changes), 4) Automated delivery (SSIS/Synapse/Notebooks, SQL Agent, schedulers).
- Prioritization formula (example weights): utility (25), strategic vs tactical (20), complexity (15), time (20), regulatory (20) → score to rank work.
- Delivery sources/destinations:
  - From: SQL Servers (internal/external) and CIP Tabular Model.
  - To: Power BI Service, SSRS Insights, applications (being replaced by ALOHA), and ad‑hoc PBI Desktop/Excel.
- Standards:
  - Wrap SQL outputs in stored procedures for control and server performance.
  - Use Power Query for Tabular imports; live connection with custom RLS.
  - Custom RLS concatenates attributes like `UserStatus + UserType + BranchName + ADUserName + Username + AdviserCode`; security state synced daily from Reference DB.
- My learnings:
  - Treat BI enhancement requests as schema evolution tasks; route through versioned release.
  - Formalize prioritization to triage the heavy inflow of data tickets consistently.

### 07. Learning CIP Data Integration Catalogue
Source: [07.-Learning-CIP-Data-Intergration-Catalogue_2569011201.html](Confluence-space-export-205412.html/07.-Learning-CIP-Data-Intergration-Catalogue_2569011201.html)

- Technologies in use (legacy + newer): SQL Agent Jobs, SSIS packages, Task Scheduler, PowerShell.
- Hosting:
  - Legacy: `SVSQLCIP\SQLCIP` and `SVSCHED2k8001`.
  - New: `KAPSQLDAT-XXX`.
- Naming conventions:
  - Stored procedures: `dbo.usp_*` or schema‑scoped by business function (e.g., `hr.usp_UpdateEmployeeSalary`).
  - SSIS: store packages on file server (preferred) over local C drive.
  - SQL Agent Jobs: `[Process Grouping] - [Specific Process]` and `Logging - [Thing being logged]` for monitoring jobs.
- SSIS Catalogue: comprehensive listing of processes; most new work orchestrated via SQL Agent.
- Linked functional specs: IRD Automated Reporting Engine; APEX/MMC New Client File; Project Alpha FSS.
- My learnings:
  - Inventory and standardize job/package names for searchability and incident response.
  - Prefer SQL Agent + SSIS for deterministic scheduling; document CmdExec jobs carefully.

### 08. Learning CRM Data Integrations (SQL)
Source: [2567929942.html](Confluence-space-export-205412.html/2567929942.html)

- DBA logging exists to track outbound connections from `CRM_MSCRM`.
- High‑level integration map:
  - CIP Data Platform (Synapse pipelines) — Outbound: pulls CRM client/portfolio data into DW → Tabular.
  - CIP Tabular Model — Inbound: brings holdings/asset data into CRM breach service/front end.
  - SSRS (Insights) — Outbound: many reports hitting CRM SQL objects.
- My learnings:
  - CRM is both a source and a consumer; bidirectional integrations require careful performance and locking considerations.
  - Monitor and govern outbound connections to prevent unmanaged dependencies.

### 09. Learning IRD Automated Reporting Engine
Source: [09.-Learning-IRD-Automated-Reporting-Engine_2568126587.html](Confluence-space-export-205412.html/09.-Learning-IRD-Automated-Reporting-Engine_2568126587.html)

- Objective: Automate monthly IRD income tax reporting to replace heavy manual processes.
- Outputs per entity/type: RWT, NRWT, IPS (Interest), DWT, AIL — potentially ~15 files monthly across entities.
- Engine:
  - SSIS package: “IRD File Automation - DataServices - Prod.dtsx”.
  - Control tables and data quality rules: entity/type mappings, validation before file creation.
  - Data Validity Engine to avoid IRD portal rejections and mis‑rated taxes due to missing IRD numbers.
  - File Delivery Mechanism executes core SPs:
    - Example: `EXEC DataServices.dbo.usp_IRDReportingData '2022-10-01','2022-10-31','1','',''`
    - Example staging checks: `--exec DataServices.dbo.usp_IRD_RWTFile 'Custodial Services Limited','Paying'`
- My learnings:
  - Treat tax file pipelines as compliance‑critical; embed validations early and log comprehensively.
  - External portal acceptance criteria must drive schema and formatting rules of exports.

---

What I have learned overall (Internal topic)
- Legacy to target: from `SVSQLCIP\SQLCIP` and ad‑hoc jobs to `KAPSQLDAT‑XX` and governed SSIS/Agent orchestration.
- Semantic hubs: SSAS Tabular and ReferenceBI (RLS inputs) are the central contract for BI and security.
- Governance is procedural: Service Portal for access, Git/PRs for report/code changes, formal prioritization for work intake.
- Upcoming shift: ALOHA/ADS/RADS will change integration boundaries; prepare API and replication aware patterns and re‑establish RLS.

