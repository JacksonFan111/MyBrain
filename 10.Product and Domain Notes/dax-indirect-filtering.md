## Power BI DAX — indirect filtering and virtual relationships

Source: `Confluence-space-export-205412.html/DAX---Indirect-filtering-pattern_3107192894.html`

### Pattern summary
- Bridge unrelated dimensions via shared facts using `FILTER`, `LOOKUPVALUE`, `CALCULATETABLE` and `TREATAS`.
- Keep measures robust to single/multi/none selections using `VALUES`.

### Use cases (refactored measures)
- Count clients holding unlisted funds by filtering Funds Under Management for assets where Asset Class=Equity, Asset Type=Fund, Market Code ∈ {NZUT,NZUL}; count distinct Portfolio Service IDs.
- Sum transaction amounts for unlisted funds by deriving AssetKeys from FUM and applying with `TREATAS` onto Asset Transaction.
- Total FUM for a selected service level: capture `VALUES('Account'[Service Level])`, derive AssetKeys, and apply both filters.
- Percentage of MySTART transactions over equity unlisted funds: derive AccountKeys for MySTART and AssetKeys for equity+funds+NZUT/NZUL; compute ratio of two `CALCULATE` results with `TREATAS`.

### When to use TREATAS despite existing relationships
- To override inactive/ambiguous relationships, compose precise multi-table conditions, or in live connection models where relationships cannot be altered.

### Guidance
- Prefer model relationships when possible; use `TREATAS` for advanced cross-domain logic and explicit context passing.
- Validate performance: heavy `LOOKUPVALUE` inside `FILTER` can be expensive; consider precomputed columns or optimized bridges when necessary.

