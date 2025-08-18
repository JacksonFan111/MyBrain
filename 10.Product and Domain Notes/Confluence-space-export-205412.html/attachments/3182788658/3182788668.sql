-- This is the The Summary

-- STEP 1 PARAMETERS: filter equity contracts for the last 3 months based on AsAtDate
DECLARE @StartDate DATE = '2024-01-01'--DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));
DECLARE @EndDate DATE = '2024-12-31';--CAST(GETDATE() AS DATE);

-- STEP 2: Roll up detailed trades to Portfolio (LedgerID) level with entity and currency breakdown
WITH DetailedTrades AS (
    -- Capture per-trade metrics, include currency lookup via StCurrencies
    SELECT DISTINCT
	    t.AccID AS AccountID,                    -- Original AccID field, renamed for clarity
        ec.LedgerID                             AS PortfolioNo,      -- Portfolio key

        CAST(ec.Quantity AS BIGINT)             AS Quantity,         -- Net units traded
        CAST(ec.Value AS DECIMAL(18,2))         AS Value,       -- Gross contract value
        -- Raw brokerage in original currency
        CAST(
            CASE WHEN t.DrCr = 'C' THEN  t.Amount
                 WHEN t.DrCr = 'D' THEN -t.Amount
            END AS DECIMAL(18,2)
        )                                        AS RawBrokerage,
        -- Original currency code via lookup table

        cur.ShortName                           AS CurrencyCode,
        -- Contract as-of date for filtering
        CONVERT(date, ec.AsAtDate)              AS ContractAsAtDate
    FROM ace.dbo.AcTransaction AS t
	LEFT JOIN ace.dbo.AcBatchHeader AS bh
    ON bh.BatchID = t.BatchID               -- Join to get batch header info
	AND bh.Status = 'C' -- Meanin gat the Accoutning Transaction batch level is Completed
    LEFT JOIN ace.dbo.EqContracts    AS ec
        ON ec.AcTransReference = t.Reference -- this the so caleld Cotnract No , link EQ to AC
		AND ec.BatchID = t.BatchID -- The Batch ID is the also important to show how many Batch in one Tansaction
    -- Lookup original currency definition
    LEFT JOIN ace.dbo.StCurrencies   AS cur
        ON t.CurrencyID = cur.ID
  
    WHERE
        t.AccID        = 'WHOLESALE'           -- Wholesale account filter
        AND t.Amount   IS NOT NULL
		AND ec.Status <> 'D' -- not Deleted 
        -- Only include contracts with AsAtDate in the last 3 months
        AND CONVERT(date, ec.AsAtDate) BETWEEN @StartDate AND @EndDate
)
-- Aggreate the CTEs Resutls
SELECT DISTINCT
    dt.AccountID,
    dt.PortfolioNo,                            -- Portfolio-level identifier
    m.ClientName       AS EntityName,         -- Entity (client) name
	m.ClientName2,  
	m.CountryID AS ClientCountryID,
	ctry.Name AS CountryName,                    -- Country name from Countries lookup from Address subset
	--
    addr.AddressLine1,
	addr.AddressLine2,
	addr.AddressLine3,
	addr.AddressLine4,
	addr.PostCode,
	--
	-- What type of client (e.g., "Institution", "Private")
    m.ClientTypeID,                          -- Client type identifier
	ClientType.Description   AS    ClientType,
	-- Branch where the client relationship is managed
	m.BranchID,                              -- Client branch identifier
    dt.CurrencyCode,                           -- Currency for this aggregation

    -- Total number of trades
    COUNT_BIG(*)                              AS TradeCount,
    -- Total units traded
    SUM(dt.Quantity)                          AS TotalQuantity,
    -- Total gross trade value
    SUM(dt.Value)                        AS TotalValue,

    -- Brokerage revenue in original currency
    SUM(dt.RawBrokerage)                      AS RawBrokerage


FROM DetailedTrades AS dt
-- Join to client master to get entity name
LEFT JOIN ace.dbo.StClients_Master AS m
    ON m.LedgerID = dt.PortfolioNo
	-- Decode client type code (Institution vs. Private)
LEFT JOIN ace.dbo.StClientTypes			ClientType -- joins to bring in the Client type DESC
		ON ClientType.ID	=	m.ClientTypeID
-- Address join to find the master mailing address
LEFT JOIN (
        ace.dbo.StClientAddress AS caa
        INNER JOIN ace.dbo.StAddresses   AS addr
            ON caa.AddressID = addr.ID
    )
        ON m.LedgerID = caa.LedgerID
-- Country lookup for the address
    LEFT JOIN ace.dbo.StCountries       AS ctry
        ON addr.CountryID = ctry.ID
WHERE 1=1 -- ZB = Zero Breakerage , HQ = Headquarder , PV = Private, IN = Institution
	AND caa.AddressTypeID='M' --- Anyaddress type that realted to the master
	AND m.ClientTypeID='IN' -- mean institutional Clients
    AND m.Status = 'A' -- Active
    --AND m.CountryID NOT IN ('NZL') -- only focus on foreign clients, not registered for tax in NZ


	--
	--AND dt.PortfolioNo = '275350'
GROUP BY
    dt.AccountID,
	dt.PortfolioNo,                            -- Portfolio-level identifier
    m.ClientName       ,         -- Entity (client) name
	m.ClientName2,  
	m.CountryID ,
	ctry.Name,                    -- Country name from Countries lookup from Address subset
	addr.AddressLine1,
	addr.AddressLine2,
	addr.AddressLine3,
	addr.AddressLine4,
	addr.PostCode,
	-- What type of client (e.g., "Institution", "Private")
    m.ClientTypeID,                          -- Client type identifier
	ClientType.Description,
	-- Branch where the client relationship is managed
	m.BranchID,                              -- Client branch identifier
    dt.CurrencyCode                           -- Currency for this aggregation

Order By dt.PortfolioNo
