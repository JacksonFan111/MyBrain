## SSRS row-level security (RLS) — multi-parameter pattern

Source: `Confluence-space-export-205412.html/Step-by-step-SSRS-RLS-set-up_3082747942.html`

### Parameter chain
- `@UserName` (hidden/internal; e.g., `=User!UserID`).
- `@Branch` (multi-select; dataset filtered by `@UserName`).
- `@Adviser` (multi-select; dataset filtered by `@UserName`, `@Branch`).
- `@AdviserCode` (multi-select; dataset filtered by `@UserName`, `@Adviser`).

Order in Report Data → Parameters must be: UserName → Branch → Adviser → AdviserCode.

### Shared datasets (examples)
- Branch list:
  - `SELECT DISTINCT BranchName FROM ReferenceBI.dbo.vw_BISecurityTables WHERE ADUserName = @UserName ORDER BY BranchName`
- Adviser list:
  - `SELECT DISTINCT AdviserName FROM ReferenceBI.dbo.vw_BISecurityTables WHERE ADUserName=@UserName AND BranchName IN (@Branch)`
- Adviser code list:
  - `SELECT DISTINCT AdviserCode FROM ReferenceBI.dbo.vw_BISecurityTables WHERE ADUserName=@UserName AND AdviserName IN (@Adviser)`

### Main dataset filter template
```
WHERE a.ADUserName = @UserName
  AND a.BranchName IN (@Branch)
  AND a.dsl_PrimaryAdviserIdName IN (@Adviser)
  AND a.AdviserID IN (@AdviserCode)
```

### Tips and pitfalls
- Ensure multi-value is enabled for dependent parameters; SSRS expands `(@Param)` appropriately.
- Data type alignment for parameter values and columns (avoid implicit conversions).
- Consider an `<All>` row convention if needed; guard logic accordingly.
- Enable remote errors on SSRS for debugging SQL issues.

