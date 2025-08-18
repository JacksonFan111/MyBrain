## NZXWT — recon issues and joining refresher

This document consolidates the NZXWT recon analysis and a practical refresher on table joins across `CRAIGS_PROD_Main`, CRM, and related servers. Links to source HTMLs are included.

### Issue 03 recon — CountryCity vs ContactDetail
Source: [NZXWT-Issues-03-recon_3045753268.html](Confluence-space-export-205412.html/NZXWT-Issues-03-recon_3045753268.html)

- Finding:
  - `CountryCity` entry Id '1673' maps `CityName = 'Sydney'` to New Zealand erroneously.
  - Verification shows 71 `ContactDetail` records for 'Sydney' correctly have Country = Australia via `PCD.Country_Id` → `Country`.
  - Therefore, error is isolated to `CountryCity`; no downstream impact on `ContactDetail` or `Portfolio`.
- Verification query confirms:
  - `ContactDetailCountry` = Australia while `CountryCityMappedCountry` = New Zealand for the same city when joined by name.
- Fix plan:
  - Update `CountryCity.Country_Id` for Id '1673' to Australia; verify; optionally scan for other incorrect entries.
- My learnings:
  - `CountryCity` used as lookup; not an enforced FK for `ContactDetail.Country_Id` in this context; textual joins can surface inconsistencies without affecting authoritative FK columns.

### Joining refresher — CRAIGS_PROD_Main and CRM
Source: [NZXWT-Refresher---hwo-to-join-tables_3060400310.html](Confluence-space-export-205412.html/NZXWT-Refresher---hwo-to-join-tables_3060400310.html)

- Core anchors and FKs:
  - `Portfolio (Id)` ↔ `Entity (Id)` via `Portfolio.Client_Id`; `UserModel` via `Entity.IdentityUser_Id`.
  - Valuation lineage: `PortfolioValuationHistoryHeader.Portfolio_Id → Portfolio.Id`; `Detail.PortfolioValuationHistoryHeader_Id → Header.Id`; `Detail.Asset_Id → Asset.Id`; currency joins.
  - Roles: `RoleEntityLink.Entity_Id → Entity.Id`, `RoleEntityLink.Role_Id → Role.Id`.
  - Holdings: `PortfolioAssetHolding.Portfolio_Id → Portfolio.Id`, `PortfolioAssetHolding.Asset_Id → Asset.Id`; `PortfolioCashHolding.Currency_Id → Currency.Id`.
  - CRM joins often through linked servers and matching references (e.g., PortfolioReference, PortfolioService IDs).
- System queries to enumerate PKs/FKs:
  - Use `sys.foreign_keys`, `sys.foreign_key_columns`, `sys.indexes`, and `INFORMATION_SCHEMA` views to extract relationship maps.
- Practical SELECT patterns:
  - Portfolio → Entity → UserModel
  - Valuation header/detail → Portfolio → Asset
  - RoleEntityLink → Role → Entity
  - Asset/Cash holdings → Portfolio → Asset/Currency
- My learnings:
  - Prefer INNER vs LEFT join purposefully; ensure join columns indexed; document implicit relationships when FKs aren’t enforced.
  - Build a living ERD/data dictionary from system views and code usage; reconcile CRM linkages by reference keys.

---

What I have learned overall (NZXWT)
- Validate authoritative FK columns before assuming lookup-table errors propagate.
- Use system catalogs to extract an accurate map of relationships; confirm with real join usage.
- Maintain a minimal reference of canonical joins for valuations, holdings, and access/roles to accelerate analysis.

