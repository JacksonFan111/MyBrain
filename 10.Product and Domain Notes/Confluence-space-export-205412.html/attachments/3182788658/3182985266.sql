--This is the details
-- PARAMETERS: filter equity contracts for the last 3 months based on AsAtDate
DECLARE @StartDate DATE = '2024-01-01'--DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));
DECLARE @EndDate DATE = '2024-12-31';--CAST(GETDATE() AS DATE);
DECLARE @PortfolioNo VARCHAR(20) = '275350'
-- STEP 1 Cleaned and annotated SQL query For  Wholesale account transactions with Foreign client details
SELECT DISTINCT 
    CONVERT(date, ec.AsAtDate) AS ContractAsAtDate,
	CONVERT(date, bh.TransDate) AS BatchHeaderTransDate,
    --t.CompanyID,
    t.AccID AS AccountID,                    -- Original AccID field, renamed for clarity
    t.BatchID,                               -- Batch identifier linking to batch header each batch of the Trasactions
	--l.Name AS LedgerName,   --- Accoutning Ledger Name for the client 
	--l.Type AS LedgerType,   --Accoutning Ledger type

	-- Translate numeric type codes into readable descriptions 
	at.Description AS Accounttype,
	 -- Portfolio number from the equity contract side (client ledger reference)
    ec.LedgerID AS PortfolioNo,              -- Portfolio number from equity contracts

	 -- Pull basic client info: active status and names
    m.Status,                                -- Client status from the Master clients
    m.ClientName,                            -- Client primary name
    m.ClientName2,                           -- Client secondary name
    m.CountryID AS ClientCountryID,                             -- Client country identifier from master Clinets
	ctry.Name AS CountryName,                    -- Country name from Countries lookup from Address subset

	-- What type of client (e.g., "Institution", "Private")
    m.ClientTypeID,                          -- Client type identifier
	ClientType.Description   AS    ClientType,

	-- Branch where the client relationship is managed
	m.BranchID,                              -- Client branch identifier
	br.Name AS BranchName,

	-- Parent company ID (for subsidiaries or group structures)
    cp.ParentClientID,                       -- Parent client ID for hierarchical relationships

	-- The contract reference and what kind of contract this is
	t.[Reference] AS ContractNo,             -- Contract reference from transaction
    td.Description AS [ContractType],                          -- Description of transaction from lookup
    CONVERT(date, ec.ContractDate) AS ContractDate,  -- Official date when the contract was agreed


    -- Map CurrencyID to human‐readable
    
    -- FX rate relative to NZD
	/*
       FX rate: normalize brokerage amounts into NZD based on currency
       "1" = NZD (1:1), "2" = AUD (use USD→AUD / USD→NZD ratio)
    */
    fxRate = CONVERT(float, CASE
        WHEN t.CurrencyID = '1' THEN 1.000000
        WHEN t.CurrencyID = '2' THEN ROUND(f1.currentRate / f.currentRate, 6)
    END),
    -- Number of shares or units traded
    ec.Quantity,
    -- Price per share or unit
    ec.Price,
    -- Total contract value (Quantity × Price)
    ec.Value,

    /* Raw brokerage fee: positive for credit, negative for debit
       Traders: brokerage is the commission cost on each trade */
    RawBrokerage = CASE
        WHEN t.DrCr = 'C' THEN  t.Amount    -- credit increases brokerage
        WHEN t.DrCr = 'D' THEN -t.Amount    -- debit decreases brokerage
    END,

    /* Translate currency ID into currency code for clarity */
    CurrencyID = CASE
        WHEN t.CurrencyID = '1' THEN 'NZD'
        WHEN t.CurrencyID = '2' THEN 'AUD'
    END,

    /* Convert brokerage into NZD for consistent reporting
       Traders and accountants: compare all fees in one base currency */
    NZDBrokerage = CONVERT(float, CASE
        WHEN t.CurrencyID = '1' AND t.DrCr = 'C' THEN  t.Amount
        WHEN t.CurrencyID = '1' AND t.DrCr = 'D' THEN -t.Amount
        WHEN t.CurrencyID = '2' AND t.DrCr = 'C' THEN  ROUND(f1.currentRate / f.currentRate * t.Amount, 2)
        WHEN t.CurrencyID = '2' AND t.DrCr = 'D' THEN -ROUND(f1.currentRate / f.currentRate * t.Amount, 2)
    END),

    -- Debit/Credit indicator for audit trails
    t.DrCr,

    /* Reference FX rates for troubleshooting: AUD↔USD and NZD↔USD
        analogy: think of exchange rates like conversion factors between game scores */
    FXUSDAUD = CASE
        WHEN t.CurrencyID = '1' THEN 1.000000
        WHEN t.CurrencyID = '2' THEN ROUND(f.currentRate, 6)
    END,
    FXUSDNZD = CASE
        WHEN t.CurrencyID = '1' THEN 1.000000
        WHEN t.CurrencyID = '2' THEN ROUND(f1.currentRate, 6)
    END

-- Main transaction table from ACE accounting system
FROM ace.dbo.AcTransaction AS t
-- Pull batch header details (date, status, etc.)
LEFT JOIN ace.dbo.AcBatchHeader AS bh
    ON bh.BatchID = t.BatchID               -- Join to get batch header info
	AND bh.Status = 'C' -- mean the Batch had been complted
-- Decode transaction type IDs into human-friendly descriptions
LEFT JOIN ace.dbo.AcTransDesc AS td
    ON td.ID = t.DescriptionID              -- Join to decode transaction descriptions
--- Eq Stand for the Equaity Trading Table,-- Link to equity contracts for trade-specific fields (quantity, price, dates)
LEFT JOIN ace.dbo.EqContracts AS ec
    ON ec.AcTransReference = t.Reference    -- Link to equity contracts via reference
	AND ec.BatchID = t.BatchID -- The Batch ID is the also important to show how many Batch in one Tansaction
-- Dimension table for ledger definitions (names, types)
LEFT OUTER JOIN ace.[dbo].[AcLedger] l
ON l.ID = ec.LedgerID
-- Map ledger type codes into readable account categories
inner join ace.dbo.AccountTypes at 
on at.ID = l.Type
-- Lookup currency details if needed
LEFT JOIN ace.dbo.StCurrencies AS cur
    ON ec.CurrencyID = cur.ID   -- Currency lookup
-- Fetch historical FX rates (USD→AUD and USD→NZD) based on contract date
LEFT JOIN fusion.dbo.FxRate f 
    ON f.rateDate <= ec.ContractDate 
   AND f.fxRateID = 44                              -- USD→AUD
LEFT JOIN fusion.dbo.FxRate f1 
    ON f1.rateDate <= ec.ContractDate 
   AND f1.fxRateID = 53                             -- USD→NZD

---ST is the String map modeule- Master String map related inforamtion, Ledger ID seems to be a main Key in this table and its linked to differtetre ID (ClientType, Country ec.)
LEFT JOIN ace.dbo.StClients_Master AS m
    ON m.LedgerID = ec.LedgerID             -- Join to client master data via LedgerID
-- Decode client type code (Institution vs. Private)
LEFT JOIN ace.dbo.StClientTypes			ClientType -- joins to bring in the Client type DESC
		ON ClientType.ID	=	m.ClientTypeID
-- Decode branch codes into branch names
LEFT JOIN ace.[dbo].[StBranches] br
ON br.ID	=	m.BranchID
-- Parent-child relationship table for client hierarchies
INNER JOIN dbo.StClientParents AS cp
    ON m.LedgerID = cp.ClientID             -- Hierarchical parent relationship
-- Advisor assignment indicating which broker advises this client
INNER JOIN dbo.StClientAdvisor AS ca
    ON m.LedgerID = ca.AccountID            -- Advisor assignment for client

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

WHERE 1=1 --Branch >>  ZB = Wholesale Branch , HQ = Headquarder , Client type >> PV = Private, IN = Institution

    AND t.AccID = 'WHOLESALE'                   -- Filter for wholesale account
    AND t.Amount IS NOT NULL             -- Exclude transactions without amounts

	AND caa.AddressTypeID='M' --- Anyaddress type that realted to the master
	AND m.ClientTypeID='IN' -- mean institutional Clients
    AND m.Status = 'A' -- Active

    --AND m.CountryID NOT IN ('NZL') -- only focus on foreign clients, not registered for tax in NZ
	AND  ec.Status <> 'D' -- This status not in string maps, likly Mean Equaty Contracts not deleted
	--
	--AND ec.AsAtDate Between '2024-01-01' and '2024-03-31'
	
	AND ec.AsAtDate Between @StartDate and @EndDate
	AND ec.LedgerID = @PortfolioNo
	--AND ec.AsAtDate = '2025-03-31'
	--AND t.CurrencyID NOT IN ('1','2')
	--AND t.Reference = '12777384-00' -- to show case there are differnet batch insdie a Same Cotraact
	--AND ec.LedgerID = '275350'


