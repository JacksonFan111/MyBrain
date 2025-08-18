/**************************************************************
Script Development Section

Last Author: Jackson Fan
Last Modified: 
Purpose: This script executes linked server Ace holdings stored procedures,
         collects results into a temporary table, and outputs the final results.

**************************************************************/

-- Step 0: Drop the temp tables if they exist
IF OBJECT_ID('tempdb..#aceAccountHolding') IS NOT NULL DROP TABLE #aceAccountHolding;
IF OBJECT_ID('tempdb..#AccountIDs') IS NOT NULL DROP TABLE #AccountIDs;
IF OBJECT_ID('tempdb..#FusionPrice') IS NOT NULL DROP TABLE #FusionPrice;

-- SSRS Related User Input Parameters
DECLARE @InputDate DATE = GETDATE(); -- Set this as a parameter in SSRS or hardcode for testing

-- Calculate the AsAtDate
DECLARE @AsatDate DATE = 
    CASE 
        WHEN DATENAME(WEEKDAY, DATEADD(DAY, -DAY(@InputDate), @InputDate)) = 'Saturday' THEN DATEADD(DAY, -1, DATEADD(DAY, -DAY(@InputDate), @InputDate))
        WHEN DATENAME(WEEKDAY, DATEADD(DAY, -DAY(@InputDate), @InputDate)) = 'Sunday' THEN DATEADD(DAY, -2, DATEADD(DAY, -DAY(@InputDate), @InputDate))
        ELSE DATEADD(DAY, -DAY(@InputDate), @InputDate)
    END;

-- Step 1: Create a Temp table to hold the list of Account IDs
CREATE TABLE #AccountIDs (AccID CHAR(12));

INSERT INTO #AccountIDs (AccID)
VALUES 
    ('276485'), ('276486'), ('670169'), ('BOOKINGSW'),
    ('CANCCROSS'), ('DUNEDIN'), ('ERROS'), ('FACILITATION'), 
    ('FACW'), ('FCG1'), ('FCG2'), ('FCG3'), 
    ('FITRADING'), ('FXARB'), ('HEADOFFICE'), ('IXARB'), 
    ('IXTRADING'), ('MMHEDGE'), ('RETAILBULK'), ('RVPFCG1'), 
    ('TRADING'), ('TRADINGW'), ('VWAP'), ('WSBULK'), 
    ('ZESPRI');

-- Step 2: Create the #aceAccountHolding table
CREATE TABLE #aceAccountHolding (
    AccID                VARCHAR(MAX),
    CompanyID           VARCHAR(MAX),
    HoldType            VARCHAR(MAX),
    Security            VARCHAR(MAX),
    Quantity            INT,
    PendingQuantity     INT,
    Currency            VARCHAR(150),
    Amount              FLOAT,
    PendingAmount       FLOAT,
    OperatorID          VARCHAR(MAX),
    CumBals             VARCHAR(MAX),
    CABalance1Desc      VARCHAR(MAX),
    CABalance1          VARCHAR(MAX),
    CABalance2Desc      VARCHAR(MAX),
    CABalance2          VARCHAR(MAX),
    CABalance3Desc      VARCHAR(MAX),
    CABalance3          VARCHAR(MAX),
    CABalance4Desc      VARCHAR(MAX),
    CABalance4          VARCHAR(MAX),
    CABalance5Desc      VARCHAR(MAX),
    CABalance5          VARCHAR(MAX),
    AccName             VARCHAR(MAX),
    SecName             VARCHAR(MAX),
    ExchangeID          VARCHAR(MAX),
    SecCode             VARCHAR(MAX)
);

-- Step 3: Execute the stored procedure for each account ID and collect results
DECLARE @CurrentAccountID CHAR(12);
DECLARE account_cursor CURSOR FOR
SELECT AccID FROM #AccountIDs;

OPEN account_cursor;
FETCH NEXT FROM account_cursor INTO @CurrentAccountID;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @DynamicSQL NVARCHAR(MAX);
    SET @DynamicSQL = N'
        INSERT INTO #aceAccountHolding (
            AccID, CompanyID, HoldType, Security, Quantity, PendingQuantity, Currency,
            Amount, PendingAmount, OperatorID, CumBals, CABalance1Desc, CABalance1,
            CABalance2Desc, CABalance2, CABalance3Desc, CABalance3, CABalance4Desc,
            CABalance4, CABalance5Desc, CABalance5, AccName, SecName, ExchangeID, SecCode
        )
        EXEC [AACARPTSRV].[ace].dbo.geAcHold 
            @pParentID = NULL,
            @pAccountID = ''' + @CurrentAccountID + N''',
            @pCompany = NULL,
            @pHoldType = NULL,
            @pCommodity = NULL,
            @pCurrency = NULL,
            @pAsAtDate = ''' + CONVERT(NVARCHAR, @AsatDate, 23) + N''',
            @pKeyTypeID1 = NULL,
            @pKeyTypeID2 = NULL,
            @pKeyTypeID3 = NULL,
            @pKeyValue1 = NULL,
            @pKeyValue2 = NULL,
            @pKeyValue3 = NULL,
            @pExchangeID = NULL,
            @pSecCode = NULL,
            @pPopGNTable = ''N'';';

    EXEC sp_executesql @DynamicSQL;

    FETCH NEXT FROM account_cursor INTO @CurrentAccountID;
END;

CLOSE account_cursor;
DEALLOCATE account_cursor;

-- Step 4: Get the #FusionPrice table
CREATE TABLE #FusionPrice (
    AssetCode VARCHAR(MAX),
    ExchangeCode VARCHAR(MAX),
    AssetStatus VARCHAR(10),
    IssueStatus VARCHAR(MAX),
    AssetName VARCHAR(MAX),
    askPrice FLOAT,
    bidPrice FLOAT,
    lastPrice FLOAT,
    priceDate DATE,
    dataProviderID INT
);

INSERT INTO #FusionPrice
SELECT DISTINCT
    a.code AS AssetCode,
    e.code AS ExchangeCode,
    CASE WHEN a.status = 1 THEN 'Active' ELSE 'Inactive' END AS AssetStatus,
    i.status AS IssueStatus,
    i.name AS AssetName,
    ph.askPrice,
    ph.bidPrice,
    ph.lastPrice,
    ph.priceDate,
    p.dataProviderID
FROM [AACARPTSRV].[fusion].dbo.Asset a
JOIN [AACARPTSRV].[fusion].dbo.Exchange e ON e.exchangeID = a.exchangeID
JOIN [AACARPTSRV].[fusion].dbo.Issue i ON i.issueID = a.issueID
LEFT JOIN [AACARPTSRV].[fusion].dbo.Price p ON p.assetID = a.assetID
LEFT JOIN [AACARPTSRV].[fusion].dbo.PriceHistory ph ON ph.priceID = p.priceID
WHERE a.status = 1
AND ph.priceDate = @AsatDate;

-- Step 5: Join the two temp tables together and output the final results

--DECLARE @AsatDate DATE = '2024-07-31' -- put here for testing


SELECT 
    aah.AccID AS [Account ID], 
    aah.AccName AS AccountName, 
    aah.CompanyID AS Company, 
    aah.HoldType AS HoldType, 
    aah.Security AS SecurityID, 
    aah.SecName AS SecurityName, 
    aah.Quantity AS Quantity,
    CASE
        WHEN aah.Quantity > 0 THEN 'Long'
        WHEN aah.Quantity < 0 THEN 'Short'
        ELSE NULL
    END AS [Position Flag],
    aah.Currency, 
    aah.Amount, 
    ROUND(aah.Amount / NULLIF(aah.Quantity, 0), 2) AS Unit_cost,
    aah.ExchangeID AS Exchange, 
    aah.SecCode AS [Exchange Security],
	fp.askPrice,
	fp.bidPrice,
	fp.lastPrice,
	--fp.priceDate,
	--
	-- Calculated column to flag if PX_LAST is within the bid/ask range
    CASE
        WHEN fp.lastPrice <= COALESCE(fp.askPrice, fp.lastPrice) AND fp.lastPrice >= fp.bidPrice THEN 'YES'
        ELSE 'NO'
    END AS PriceWithinRange,

	-- Calculated column to determine the final price based on the logic
	CASE
		WHEN fp.lastPrice <= COALESCE(fp.askPrice, fp.lastPrice) AND fp.lastPrice >= fp.bidPrice THEN fp.lastPrice
		WHEN aah.Quantity > 0 THEN fp.bidPrice -- Use Bid Price if buying (Long Position)
		WHEN aah.Quantity < 0 THEN COALESCE(fp.askPrice, fp.lastPrice) -- Use Ask Price if selling (Short Position), fallback to lastPrice
		ELSE NULL
	END AS FinalPrice,

	-- Calculated column for Market Value (CCY)
	aah.Quantity * 
	CASE
		WHEN fp.lastPrice <= COALESCE(fp.askPrice, fp.lastPrice) AND fp.lastPrice >= fp.bidPrice THEN fp.lastPrice
		WHEN aah.Quantity > 0 THEN fp.bidPrice
		WHEN aah.Quantity < 0 THEN COALESCE(fp.askPrice, fp.lastPrice) -- Use Ask Price if selling (Short Position), fallback to lastPrice
		ELSE NULL
	END AS MarketValueCCY,

	--
    CONVERT(VARCHAR(10), @AsatDate, 101)  AS AsAtDate, 
   CONVERT(VARCHAR(10), GETDATE(), 101)  AS TransactionDate
FROM #aceAccountHolding aah
LEFT JOIN #FusionPrice fp ON aah.ExchangeID = fp.ExchangeCode COLLATE Database_Default 
AND aah.SecCode = fp.AssetCode COLLATE Database_Default;


-- Cleanup: Drop temporary tables if needed
--DROP TABLE IF EXISTS #aceAccountHolding;
--DROP TABLE IF EXISTS #AccountIDs;
--DROP TABLE IF EXISTS #FusionPrice;
