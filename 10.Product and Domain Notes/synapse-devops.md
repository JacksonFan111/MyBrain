## Azure Synapse DevOps — end-to-end framework and CI/CD handover

Sources:
- Confluence export: `Confluence-space-export-205412.html/Data-platform-DevOps-Workshop-Day-1---part-1_3255730205.html`
- Confluence export: `Confluence-space-export-205412.html/Data-Platform-DevOps-Workshop-Day-1---Part-2_3256156203.html`

### Goals
- Stand up a metadata-driven ingestion framework (ODS → DW) with robust logging and incremental logic.
- Operate consistently across DEV/UAT/PREPROD/PROD with CI/CD deployment of Synapse artifacts and SQL schema (DACPAC).

### Environment structure and source control
- Environments: DEV → UAT → PREPROD → PROD.
- Synapse workspace in DEV is Git-enabled; work in feature branches → merge to `main` → Publish.
- Publish outputs: `TemplateForWorkspace.json` and `TemplateParametersForWorkspace.json` in `workspace_publish` branch.

### Linked Services, Integration Runtimes, and secrets
- Pattern: `ls_Source_<System>` and `ls_Target...` with Self-hosted IR for on‑prem sources; Azure IR for cloud.
- Credentials via Azure Key Vault LS (e.g. `bikeyvault`): LS references vault secret names (e.g., `SourceCRM`).
- CI/CD overrides Key Vault base URL per environment; keep secret names consistent across vaults.

### Triggers and scheduling
- Centralize triggers (few, well-named). Prefer schedule or tumbling-window triggers; avoid proliferation.
- Lower envs often keep triggers disabled; enable in higher envs as part of release or post‑deploy.

### Parameterized datasets and data formats
- Reuse generic datasets with parameters (`SchemaName`, `TableName`, and/or `Query`).
- Avoid default values for dataset parameters; force explicit parameter passing from pipelines.
- For file sources, standardize CSV/Parquet settings; document edge cases.

### Framework architecture (metadata-driven)
- Master orchestration pipeline (e.g., “Master – Execute Process”): starts batch log, executes sub‑pipelines, closes batch, and notifies.
- “Load Sources – ALL” orchestrates parallel loads per source with controlled concurrency.
- Table-level pipeline (per `DataLoadID`) does the heavy lifting:
  - Parameters: `DataLoadID`, `ParentBatchId`.
  - Lookup metadata: source schema/table or `SourceQuery`, load type, watermark column/value, target.
  - Incremental logic: fetch last HWM, construct filtered source query, copy to staging, then MERGE into target.
  - Full load logic: truncate target, copy all.
  - Logging: start/finish per table, row counts, duration, errors; update new HWM.
- Framework DB tables (illustrative): `[Metadata].[DataSources]`, `[Metadata].[DataObjects]`, `BIML.DataLoad`, `BIML.DataLoadDetails`, `[ETL].[LogOverview]`, `[ETL].[LogDetails]`.

### Onboarding a new source (runnable checklist)
1. Create Linked Service(s); point to Key Vault secrets; verify connectivity on the chosen IR.
2. Register the source in the framework DB (`DataSources`).
3. Add/clone a generic dataset (parameterized) for the source.
4. Run “Metadata Discovery for <Source>” to populate `DataObjects` and initial `DataLoad` rows.
5. Configure loads in `BIML.DataLoad/Details`: load type, incremental column, optional `SourceQuery`, schedule, and target mapping.
6. Test table-level pipeline for one table (full and incremental), validate logs and row counts.
7. Enable in “Load Sources – ALL” with appropriate concurrency.

### CI/CD with Azure DevOps (workspace + DACPAC)
- Repos:
  - Synapse workspace repo (Git linked) → publish branch is the deployment artifact.
  - SQL database project repo → build to produce `.dacpac` artifact.
- Service connections: one per environment (SPN with RG Contributor + Synapse Admin roles). Ensure SPN has Key Vault get access to referenced secrets.
- Agent pools:
  - Hosted agents often sufficient; self-hosted agent allowed with `sqlpackage` capability when deploying DACPAC.

#### Release pipeline stages (classic or YAML)
- Artifacts:
  - Synapse ARM templates from `workspace_publish`.
  - DACPAC artifact from build pipeline.
- Variables / variable groups per environment:
  - `vgKeyVaultUrl`, `vgWorkspaceName`, `vgOnpremUserName`, storage account URLs, SQL server names, etc.
- Tasks per stage:
  - Synapse workspace deployment task:
    - Template: `TemplateForWorkspace.json`, Parameters: `TemplateParametersForWorkspace.json`.
    - Set resource group, workspace, service connection.
    - Override parameters for LS base URLs, Key Vault URL, usernames; optionally “delete artifacts not in template”.
  - Azure SQL Database Deployment (DACPAC):
    - Target server and DB (Synapse SQL endpoint or Azure SQL DB).
    - Auth: SQL auth or AAD/SPN; enable auto‑firewall where needed.
    - Optional arguments: `/p:BlockOnPossibleDataLoss=False` (use with governance).

### Runbook — promoting changes
1. Developer hits Publish in Synapse → templates updated.
2. Release: pick artifacts → deploy to DEV/UAT/… stages with variable group overrides.
3. Verify:
   - Synapse: pipelines/datasets present, LS connected, triggers as intended.
   - Database: schema updated; smoke tests passed.
4. Approve next stage; repeat.

### Troubleshooting and best practices
- Permissions: SPN must be Synapse Admin and have RG scope; Key Vault access for secret resolution.
- Parameterization gaps: use template-parameters-definition or pipeline overrides for special cases.
- Triggers: deploy stopped by default; explicitly enable/disable per environment.
- DACPAC pitfalls: firewall, drift, rights; confirm `sqlpackage` availability on agent.

### Handover checklist (ops)
- [ ] IR capacity and health monitored; scale nodes if throughput constrained.
- [ ] Variable groups documented per environment.
- [ ] Framework DB connection (e.g., `ls_Framework`) verified across envs.
- [ ] Metadata discovery → onboarding SOP stored in repo.
- [ ] Logging dashboards (row counts, durations, last success per table) published.

### References
- `Confluence-space-export-205412.html/Data-platform-DevOps-Workshop-Day-1---part-1_3255730205.html`
- `Confluence-space-export-205412.html/Data-Platform-DevOps-Workshop-Day-1---Part-2_3256156203.html`

