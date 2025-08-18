## CIP0335624 — CRM Client Report Recipient Analysis (BA Spec for Data Team)

### Status
- Owner: Data Team BA (acting on behalf of Compliance)
- Last updated: 2025-08-18
- Related ticket: CIP0335624

### Background
In 2024, the FMA issued guidance for providers of client money or property services. Compliance reviewed the guidance and highlighted that clients must always receive their reports, even if they nominate an alternate recipient (e.g., family member, accountant). As an initial step, Compliance requests a review of portfolios where report recipients are:
- CIP staff email addresses; and/or
- A CIP branch for physical (postal) reports.

Compliance additionally asks whether we can produce a broader view of where client reports are sent to someone other than the client, and to validate that a copy is also sent to the client.

### Objective
- Provide developers with a clear, implementable specification to produce:
  - Report A: Portfolios that have a CIP email or CIP branch as a report recipient.
  - Report B: Portfolios where reports are being sent to someone other than the client; flag if the client does/does not also receive the report.
  - Report C: A comprehensive recipient view for each report request, including portal-access recipients (via roles) and direct send recipients (email/post).

### In Scope
- CRM-based client reports and their delivery recipients (email/post/portal availability).
- Mapping recipients to client entities and to portfolio owners to determine who “the client” is per portfolio.
- Identification of CIP recipients by email domain and by branch address for physical delivery.

### Out of Scope
- Non-CRM reporting channels not recorded in CRM.
- Historical data not present in the configured CRM reporting entities.
- Remediation of CRM data quality issues (we will highlight, not cleanse).

### Stakeholders
- Compliance (requestor; Jade)
- Data Team (analytics/engineering; Zac et al.)
- CRM Team (schema/relationships; recipients, report packs, roles)

### Definitions
- Client: The portfolio’s legal owner entity. This may be an Individual or a Corporate entity (e.g., Trust, Company). A portfolio can have multiple related persons with roles (Minor, Beneficial Owner, Corporate Trustee, Trustee, Individual, Bank Account Holder). For FMA purposes, the client (owner) must receive their reports.
- Recipient (Direct): A person or address explicitly attached to a report request to receive via email or post.
- Recipient (Portal Access): A person/entity who can access the report via the client portal due to their relationship/role to the owning entity, even if not directly sent to them.
- CIP Recipient (Email): An email address under the corporate domain (e.g., @craigsip.com). Confirm exact domains with IT/HR (e.g., @craigsip.com, @craigsip.co.nz if any).
- CIP Recipient (Physical): A postal address mapped to a CIP branch location (branch address registry).

### High-level Process (as-is)
1. Report Requests are created in CRM for a given portfolio/entity and report pack/type.
2. Direct Recipients may be attached to the Report Request (email/post). Example record: CRM link shared in context.
3. Reports may also be visible on the portal based on the Report Pack’s Entity and related Roles (e.g., Trustees, Beneficial Owners) who have portal access.
4. Batches may contain multiple requests; ad hoc requests exist separately.

### Data Sources (SQL)
Known tables referenced by teams (validate exact schema and keys):
- `ReportBase` — Base reporting metadata (confirm: report requests and/or outputs registry)
- `dsl_adhocreportrequest` — Ad hoc report requests
- `dsl_reportbatch` — Batch runs grouping report requests
- `dsl_reportrequest` — Core report request entity (confirm name)
- `dsl_reportpack` — Pack/type/category of report for the request (confirm name)
- `dsl_reportrecipient` (or similar) — Direct recipients linked to a report request (confirm exact table/entity)
- CRM Entity/Account/Contact tables — Portfolio owner, related roles, and contact details
- Portal/Role linkage tables — Role-based access from Entity to persons
- Branch directory — List of CIP branch physical addresses

Reference queries provided:
```sql
SELECT TOP 10 * FROM [ReportBase];
SELECT TOP 10 * FROM [dsl_adhocreportrequest];
SELECT TOP 10 * FROM [dsl_reportbatch];
```

### Entity and Join Map (to validate)
- Report Request (`dsl_reportrequest`) → has one Report Pack (`dsl_reportpack`)
- Report Request → has many Direct Recipients (`dsl_reportrecipient`) with delivery method flags (email/post)
- Report Pack → belongs to Entity/Portfolio (owner entity id)
- Entity/Portfolio → has Roles (Minor, Beneficial Owner, Corporate Trustee, Trustee, Individual, Bank Account Holder)
- Roles → identify persons/accounts who may have portal access to the report
- Report Request → may belong to a Batch (`dsl_reportbatch`) or be ad hoc (`dsl_adhocreportrequest`)

Key IDs/joins to confirm:
- `dsl_reportrequest.reportpackid` → `dsl_reportpack.reportpackid`
- `dsl_reportrequest.entityid` or `dsl_reportpack.entityid` → owning entity/portfolio
- `dsl_reportrecipient.reportrequestid` → `dsl_reportrequest.reportrequestid`
- Role mapping: entity → role → person/contact (and portal user linkage if distinct)

### Business Rules
1. Identify the client (portfolio owner) per report request.
   - If entity is Individual: that individual is the client.
   - If entity is Corporate (trust/company): the entity is the client; persons in roles are not “the client” unless explicitly designated as owner.
2. Identify direct recipients (email and/or post) attached to the request.
3. Identify portal-access recipients via roles for the owning entity.
4. Determine CIP recipients:
   - Email: address ends with configured CIP domains (e.g., @craigsip.com). Maintain a reference list of valid domains.
   - Physical: postal address equals a known CIP branch address or clearly matches via normalized fields.
5. Determine whether “the client” (owner) also receives the report:
   - If the client has an email recipient record, count as “client receives by email”.
   - If the client has a postal recipient record, count as “client receives by post”.
   - If the client has portal access and the report is available on portal, count as “client can access via portal”.
6. Compliance flagging:
   - Flag if any non-client recipient exists AND the client does not receive by any channel (email, post, or portal access), per FMA guidance.
   - Additionally flag if a CIP recipient is the sole or primary recipient without the client receiving a copy.

### Deliverables
- Report A: Portfolios with CIP recipients
  - One row per report request (or per portfolio/report type), including:
    - Report date, report type/pack, request id, batch id (if any)
    - Owning entity/portfolio id and name
    - Recipient type (email/post/portal), recipient details
    - CIP match (email domain or branch address), match reason
    - Client-receives indicator(s): client_email, client_post, client_portal
- Report B: Reports sent to someone other than the client
  - Focus on requests where at least one non-client recipient exists; include whether client also receives
  - Include counts of recipients by type; list of relationship roles and who can access via portal
- Report C: Full recipient matrix per request
  - Tabular: all recipients (direct + inferred portal-access) with role, channel, and delivery details

### Parameters and Filters
- Date range (requested date, generated date, batch date)
- Report types/packs (optional include/exclude)
- Delivery channels (email/post/portal)
- Include portal-access recipients (boolean)
- Environment (Prod/UAT) and data as-of timestamp

### Acceptance Criteria
- Able to identify all requests with at least one CIP recipient (email domain or branch address).
- Able to identify all requests with non-client recipients and correctly flag whether the client also receives a copy (any channel).
- Client identification logic handles Individual and Corporate/trust entities correctly.
- Portal-access recipients are included when enabled and are role-derived from the owning entity.
- Outputs reconcile to a sample set validated manually in CRM (≥ 95% match on a 50-record stratified sample).

### Example SQL Skeletons (to adapt to actual schema)
Direct recipients joined to requests and packs:
```sql
WITH recipients AS (
    SELECT
        rr.reportrequestid,
        rrec.recipientid,
        rrec.recipient_email,
        rrec.recipient_postal_address_1,
        rrec.recipient_postal_city,
        rrec.recipient_postal_postcode,
        rrec.delivery_method,      -- 'email' | 'post'
        CASE WHEN LOWER(rrec.recipient_email) LIKE '%@craigsip.com' THEN 1 ELSE 0 END AS is_cip_email
    FROM dsl_reportrecipient rrec
    JOIN dsl_reportrequest rr ON rr.reportrequestid = rrec.reportrequestid
)
SELECT
    rr.reportrequestid,
    rb.reportdate,
    rp.reportpackid,
    rp.reportpack_name,
    rr.entityid AS owning_entity_id,
    recipients.recipientid,
    recipients.recipient_email,
    recipients.delivery_method,
    recipients.is_cip_email,
    CASE WHEN b.branch_id IS NOT NULL THEN 1 ELSE 0 END AS is_cip_branch_physical
FROM dsl_reportrequest rr
LEFT JOIN ReportBase rb ON rb.reportrequestid = rr.reportrequestid
LEFT JOIN dsl_reportpack rp ON rp.reportpackid = rr.reportpackid
LEFT JOIN recipients ON recipients.reportrequestid = rr.reportrequestid
LEFT JOIN ref_cip_branch_addresses b
  ON b.match_key = CONCAT_WS('|', recipients.recipient_postal_address_1, recipients.recipient_postal_city, recipients.recipient_postal_postcode);
```

Portal-access recipients inferred from roles (pseudo):
```sql
SELECT
    rr.reportrequestid,
    rr.entityid AS owning_entity_id,
    role.role_type,
    person.person_id,
    person.email AS portal_email,
    1 AS is_portal_access
FROM dsl_reportrequest rr
JOIN entity_roles role ON role.entity_id = rr.entityid
JOIN persons person ON person.person_id = role.person_id
WHERE role.portal_access_enabled = 1;
```

Client identification and flagging (pseudo):
```sql
WITH client AS (
    SELECT e.entityid, e.entity_type, e.owner_person_id, e.owner_account_id
    FROM entity e
),
direct AS (
    SELECT rr.reportrequestid, rrec.delivery_method, rrec.recipient_person_id, rrec.recipient_email
    FROM dsl_reportrecipient rrec
    JOIN dsl_reportrequest rr ON rr.reportrequestid = rrec.reportrequestid
),
portal AS (
    SELECT rr.reportrequestid, pr.person_id AS recipient_person_id
    FROM dsl_reportrequest rr
    JOIN portal_recipients pr ON pr.entity_id = rr.entityid
)
SELECT
    rr.reportrequestid,
    CASE
        WHEN c.entity_type = 'Individual' AND EXISTS (
            SELECT 1 FROM direct d WHERE d.reportrequestid = rr.reportrequestid AND d.recipient_person_id = c.owner_person_id
        ) THEN 1
        WHEN c.entity_type <> 'Individual' AND EXISTS (
            SELECT 1 FROM direct d WHERE d.reportrequestid = rr.reportrequestid AND d.recipient_person_id = c.owner_account_id
        ) THEN 1
        WHEN EXISTS (
            SELECT 1 FROM portal p WHERE p.reportrequestid = rr.reportrequestid AND p.recipient_person_id = c.owner_person_id
        ) THEN 1
        ELSE 0
    END AS client_receives_any
FROM dsl_reportrequest rr
JOIN client c ON c.entityid = rr.entityid;
```

Note: Replace table/column names with actual CRM schema names. Use reference tables for branch addresses and corporate email domains.

### CRM “Where to Click” (for manual validation)
1. Open a Report Request record in CRM (e.g., CRM main → Report Requests → select record):
   - Example link pattern: `https://crm365.craigsip.com/CRM/main.aspx?etn=dsl_reportrequest&id={GUID}&newWindow=true&pagetype=entityrecord`.
2. On the Report Request form:
   - Check the Recipients subgrid for direct email/post recipients.
   - Open the related Report Pack to confirm report type/category.
   - From Report Pack, navigate to the Entity/Portfolio.
   - From the Entity, open Roles to see related people (e.g., Trustee, Beneficial Owner) and whether they have portal access.
3. Confirm if the client (owning entity/individual) is among recipients or has portal access.

### Scenarios to Cover (Examples)
- Trust with Corporate Trustee and Beneficial Owner (e.g., client sets up family trust with corporate trustee and includes son as beneficial owner; trades in NVDA/QQQ generate contract notes). Validate which of these receive the report via direct send and/or portal access; ensure the client (trust) also receives.
- Individual client nominating their accountant by email; ensure the individual client also receives.
- CIP staff recipient used as delivery (email) or branch address as postal delivery; ensure the client also receives.

### Data Quality and Controls
- Maintain a reference table `ref_cip_email_domains` for valid CIP domains.
- Maintain `ref_cip_branch_addresses` for branch postal addresses (normalized fields).
- Normalize emails (lowercase, trim) and addresses (case, street/unit formatting) before matching.
- Log unmatched addresses and ambiguous matches for review.

### Privacy and Security
- Outputs may contain personal data; restrict access to Compliance and Data Team.
- Mask personal emails in lower environments.
- Do not export PII outside approved storage.

### Performance and Scheduling
- Initial one-off extraction for Compliance review (last 12–24 months configurable).
- Optional scheduled monthly job if ongoing monitoring is required.
- Index review on join keys; consider incremental extraction by `modifiedon`/`createdon`.

### Open Questions (for Jade/Compliance)
1. Confirm exact list of report categories/packs in scope (e.g., Contract Notes, Statements, Tax reports, Corporate Actions, etc.).
2. Confirm definition of “client” for corporate entities (is it strictly the legal entity, or do designated individuals qualify?).
3. Confirm CIP email domains and the branch address master source of truth.
4. Should portal availability alone count as “client receives” for FMA purposes, or must there be an active send (email/post)?
5. Required date range and environment (Prod snapshot vs direct live query).

### Testing Approach
- Build a 50-record stratified sample across entity types, report packs, and delivery methods.
- Manually validate in CRM via the steps above.
- Reconcile any mismatches; document reasons and adjust logic.

### Confluence
- Recommend page: “CRM Client Report Recipient Monitoring — CIP0335624” under Compliance > Reporting Controls.
- Include overview, business rules, data model, and links to SQL/Power BI artifacts.

### Implementation Notes
- Produce outputs as SQL views or a Power BI dataset with three pages (Report A/B/C) and exportable tables.
- Parameterize CIP domain and branch lists via reference tables.
- Include a “Client Receives?” boolean and channel breakdown in each output.

