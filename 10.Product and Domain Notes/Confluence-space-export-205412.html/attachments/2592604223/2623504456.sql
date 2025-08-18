/**************************************************************
Script Development Section
******************************

Last Author: Jackson Fan
Last Modified: 10.07.2024
Purpose: This script calculates the normal management fee for 
         portfolios based on the valuation data and a provided 
         fee schedule to compared with staff management fee. It uses temporary tables and a CTE 
         (Common Table Expression) to organize and process 
         the data efficiently.

**************************************************************/

-- Server = cip-sql-reporting.nzxwt.nz
-- DB = CRAIGS_PROD_MAIN

-- Unit 1: prerequisite set up and declare relevant variables, clear out all the temp tables when not needed

 --Define variables for date range and portfolio ID
--DECLARE @StartDate DATETIME = '2024-07-01';
--DECLARE @EndDate DATETIME = '2024-07-30';
--DECLARE @PortfolioID VARCHAR(50) = NULL ;
--'265840_MS' --'213018_SS' --'671690_KP' --'10178_KP'-- '248912_KP' --'673158_MS'; -- could be default to NULL
--'635981_KP'; -- This is a staff portfolio ID
--portfolio ID business user also call it ClientCode


-- Check and drop temporary tables if they already exist
IF OBJECT_ID('tempdb..#AssetTypeMapping') IS NOT NULL DROP TABLE #AssetTypeMapping;
IF OBJECT_ID('tempdb..#RankedFeeScales') IS NOT NULL DROP TABLE #RankedFeeScales;
IF OBJECT_ID('tempdb..#CalculatedRanges') IS NOT NULL DROP TABLE #CalculatedRanges;
IF OBJECT_ID('tempdb..#FeeScheduleWithPercentage') IS NOT NULL DROP TABLE #FeeScheduleWithPercentage;
IF OBJECT_ID('tempdb..#TempValuationNZD') IS NOT NULL DROP TABLE #TempValuationNZD;
IF OBJECT_ID('tempdb..#PrescribedPerson') IS NOT NULL DROP TABLE #PrescribedPerson;
IF OBJECT_ID('tempdb..#StaffManagementFee') IS NOT NULL DROP TABLE #StaffManagementFee;
IF OBJECT_ID('tempdb..#PortfolioValuationByAssetType') IS NOT NULL DROP TABLE #PortfolioValuationByAssetType;
IF OBJECT_ID('tempdb..#FinalStaffManagementFee') IS NOT NULL DROP TABLE #FinalStaffManagementFee;
IF OBJECT_ID('tempdb..#FinalNormalManagementFees') IS NOT NULL DROP TABLE #FinalNormalManagementFees;



-- Unit 2: 
-- Define and drop the PrescribedPerson temporary table , this table join with entity to get the Percribed person type
DROP TABLE IF EXISTS #PrescribedPerson;

;WITH PrescribedPerson AS (
    SELECT 'Staff' AS Type, 1 AS Id
    UNION ALL SELECT 'Staff Family', 2
    UNION ALL SELECT 'Part time Staff', 3
    UNION ALL SELECT 'Temporary Staff', 4
    UNION ALL SELECT 'Director', 5
    UNION ALL SELECT 'Director Family', 6
    UNION ALL SELECT 'Not Associated', 7
    UNION ALL SELECT 'N/A', 0
) 
SELECT * INTO #PrescribedPerson FROM PrescribedPerson;



-- Unit 3: 
-- Create and populate StaffManagementFee temporary table  FROM PortfolioCashTrade pct, the data is actually precalcualted at a date level
--it gave us the StaffManagementFee by portfolio and by branch and by FeePackage name, also we would be able to know when it is billed and paid, if the date is NULL is mean it have not been billed or paid

DROP TABLE IF EXISTS #StaffManagementFee;

;WITH StaffManagementFee AS (
    SELECT DISTINCT
        p.PortfolioReference AS ClientCode,
        p.PortfolioName AS ClientName,

		-- newly added 

		ps.code AS PortfolioStatus,
		p.PortfolioClosedDate AS PortfolioClosedDate,

		--

        pr.Type AS StaffType,
        ob.BranchName AS Branch,
        oac.CommissionCode AS AdvisorCode,
        CONVERT(VARCHAR(25), fed.DatePaid, 103) AS DatePaid, 
        CONVERT(VARCHAR(25), fed.DateBilled, 103) AS DateBilled,
		f.FeePackage_ID,
        f.Name AS FeeName,
        fp.Name AS FeePackageName,
        pct.Description AS TransactionDescription,
        pct.AmountBaseCCY AS StaffManagementFeecol
    FROM PortfolioCashTrade pct
    JOIN TradeStatus ts ON ts.Id = pct.STATUS
    JOIN TradeTypeDM tt ON tt.Id = pct.TradeType
    JOIN PortfolioOrder po ON po.Id = pct.PortfolioOrder_ID
    JOIN Portfolio p ON p.Id = po.Portfolio_ID
	JOIN PortfolioStatus ps ON p.STATUS = ps.Id -- to bring in the portfolio actual status

    JOIN dbo.OrganisationBranch ob ON ob.Id = p.OrganisationBranch_Id
    JOIN dbo.OrganisationAdvisorCode oac ON oac.Id = p.OrganisationAdvisorCode_Id
    JOIN Entity e ON e.Id = p.Client_Id
    JOIN #PrescribedPerson pr ON pr.Id = e.PrescribedPersonType
    LEFT JOIN FeeIncomeAndExpenseDetail fed ON pct.Id = fed.PortfolioCashTrade_Id
    LEFT JOIN Fee f ON f.Id = fed.Fee_Id
    LEFT JOIN FeePackage fp ON fp.Id = f.FeePackage_ID
    LEFT JOIN PortfolioFeePackage pfp ON pfp.FeePackage_ID = f.FeePackage_ID AND pfp.Portfolio_ID = p.Id
    WHERE 
	1=1
        --pr.Id NOT IN (0, 7) -- some people are staff but it is N/A on the entity i remvoed this to avoid over filtering
        AND p.RecordStatus = 1
        AND tt.id IN (444, 449, 450) -- (PortfolioFee, PortfolioManualFee, PortfolioManualFeeIncome)
        AND (f.Name LIKE '%Management Fee Staff%' OR  f.Name LIKE '%Management Fee  - Staff%') -- filter out non Management Fee
        AND fp.Name IN ('mySTART Fee Schedule', 'Craigs KS Fee Schedule', 'CIP Super Fee Schedule', 'superSTART Fee Schedule', 
                        'mySTART Staff Fee Schedule', 'Craigs KS Staff Fee Schedule', 'CIP Super Staff Fee Schedule', 
						'superSTART Staff Fee Schedule','superSTART Staff v2 Fee Schedule', 'mySTART Staff v2 Fee Schedule',
						
						-- added to handle edge cases, people tha tare staff in the past and not portfolio closed or pending closure or closing
						'mySTART Staff DO NOT USE','Craigs KS Staff DO NOT USE', 'superSTART Staff DO NOT USE',
						'mySTART Staff v2 DO NOT USE','CIP Super Staff DO NOT USE')
						--

-- 22.07.2024 JF Important logcis Update: i find out some of the portfolio have been closed and it is not showing in the result table.
-- the end users asked me to included the historical closed portfolio data in and incldued the status and closed date of portfolio.
-- from my research JOIN PortfolioStatus ps ON p.STATUS = ps.Id >> could bring in the status descrption
-- the Portfolio p have the closed date as p.PortfolioClosedDate, i also find out thoes closed staff account mostly have the DO NOT USE
-- in their Fee packages Name, the staff that have that DO NOT USE status are mostly closed.

		AND (fed.DatePaid IS NULL OR (fed.DatePaid BETWEEN @StartDate AND DATEADD(DAY, 2, @EndDate))) 
		-- above is filter by date range allow null, also added two days on the date range to avoid edge case like Enddate at 30.06.2024 but fed.DatePaid on 01.07.2024
        AND (p.PortfolioReference = @PortfolioID OR @PortfolioID IS NULL)
)
SELECT * INTO #StaffManagementFee FROM StaffManagementFee;
-- Aggregate Staff Management Fee data to the >> by portfolio and by branch and by FeePackage name level

 

DROP TABLE IF EXISTS #FinalStaffManagementFee;

SELECT 
    ClientCode,
    ClientName,
	PortfolioStatus,
	PortfolioClosedDate,
    StaffType,
    Branch,
    AdvisorCode,
	FeePackage_ID,
    FeeName,
    FeePackageName,
    TransactionDescription,
    SUM(StaffManagementFeecol) AS FinalStaffManagementFee
INTO #FinalStaffManagementFee
FROM #StaffManagementFee
GROUP BY
    ClientCode,
    ClientName,
	PortfolioStatus,
	PortfolioClosedDate,
    StaffType,
    Branch,
    AdvisorCode,
	FeePackage_ID,
    FeeName,
    FeePackageName,
    TransactionDescription;


--Unit 4: this part is to build and test how much are we going to charge if a staff not a staff anymore 
-- Create and populate NormalmanagementFee temporary table  FROM dbo.FeePackage fp, the data is actually complicated that we thought

--Unit 4.1
-- Build AssetTypeMapping temporary table
DROP TABLE IF EXISTS #AssetTypeMapping; -- to handle potential block from previous temp table run

;WITH AssetTypeMapping AS (
    SELECT * FROM (VALUES
        (NULL, NULL, 'Cash Call Account'),
        (2, 'FIX', 'Term Deposits & Debentures'),
        (4, 'UTR', 'Unitised'),
        (5, 'SHA', 'Shares'),
        (6, 'GOV', 'Government Bonds'),
        (7, 'BND', 'Bonds & Notes')
    ) AS AssetTypeMap (AssetType, ProductType, TypeName)
)
SELECT * INTO #AssetTypeMapping FROM AssetTypeMapping;


--Unit 4.2
-- Build RankedFeeScales temporary table, Provide a Ranked logics for fs.EndValue, ranked by their numeric order, why are we doing this?
-- in the FeeScale table >> the Fee Value is actually the Annualised percentage for the calculation
--becasue the original FeeScales is not really well deisgned and people don't really know where to find the annulaised percentage , so we have to Normalised the table to make it human readible
DROP TABLE IF EXISTS #RankedFeeScales

;WITH RankedFeeScales AS (
    SELECT 
        fp.Id As FeePackage_ID,
        fp.Name AS FeePackageName,
        CASE 
            WHEN fp.Id = 43 THEN 42
			WHEN fp.Id = 10 THEN 42--added the DO NOT USE situation

            WHEN fp.Id = 40 THEN 38
			WHEN fp.Id = 9 THEN 38--added the DO NOT USE situation

            WHEN fp.Id = 35 THEN 31
			WHEN fp.Id = 36 THEN 31-- added the v2 situation
			WHEN fp.Id = 8 THEN 31--added the DO NOT USE situation
			WHEN fp.Id = 22 THEN 31--added the DO NOT USE situation

            WHEN fp.Id = 50 THEN 45
			WHEN fp.Id = 11 THEN 45 --added the DO NOT USE situation
			WHEN fp.Id = 51 THEN 45 -- added the v2 situation
			

            ELSE fp.Id
        END AS Normal_FeePackage_ID,
		-- to reassign package id from staff to a normal package, Why? because we want to see if a staff not a staff how much we are going to Charge them
        CASE 
            WHEN fp.Name = 'CIP Super Staff Fee Schedule' THEN 'CIP Super Fee Schedule'
			WHEN fp.Name = 'CIP Super Staff DO NOT USE' THEN 'CIP Super Fee Schedule'--added the DO NOT USE situation

            WHEN fp.Name = 'Craigs KS Staff Fee Schedule' THEN 'Craigs KS Fee Schedule'
			WHEN fp.Name = 'Craigs KS Staff DO NOT USE' THEN 'Craigs KS Fee Schedule'--added the DO NOT USE situation

            WHEN fp.Name = 'mySTART Staff Fee Schedule' THEN 'mySTART Fee Schedule'
			WHEN fp.Name = 'mySTART Staff v2 Fee Schedule' THEN 'mySTART Fee Schedule' --added the v2 situation
			WHEN fp.Name = 'mySTART Staff DO NOT USE' THEN 'mySTART Fee Schedule' --added the DO NOT USE situation
			WHEN fp.Name = 'mySTART Staff v2 DO NOT USE' THEN 'mySTART Fee Schedule'--added the DO NOT USE situation

            WHEN fp.Name = 'superSTART Staff Fee Schedule' THEN 'superSTART Fee Schedule'
			WHEN fp.Name = 'superSTART Staff DO NOT USE' THEN 'superSTART Fee Schedule' --added the DO NOT USE situation
			WHEN fp.Name = 'superSTART Staff v2 Fee Schedule' THEN 'superSTART Fee Schedule' --added the v2 situation

            ELSE fp.Name
        END AS Normal_FeePackageName,
		-- this is to swap the original staff packages into a normal packages so we could calcualte the differences
        FORMAT(fp.AuthorisedDate, 'yyyy-MM-dd') AS AuthorisedDate,
        FORMAT(fp.CreatedDate, 'yyyy-MM-dd') AS CreatedDate,
        f.ActualisationFrequency,
        f.CalculationMethod,
        f.Name AS FeeName,
        atm.AssetType, -- from temp table 
        COALESCE(atm.TypeName, 'Cash Call Account') AS AssetTypeName, -- this is to change the NULL into 'Cash Call Account'
        fs.EndValue,
        fs.FeeValue as AnnualisedFeeInPercentage,
        ROW_NUMBER() OVER (PARTITION BY fp.Name, atm.TypeName ORDER BY fs.EndValue) AS RowNum --using row number here to partition by feepackageName , and AssetTypeName and order by End value to get rank (1,2,3,4)
    FROM dbo.FeePackage fp
    LEFT JOIN dbo.Fee f ON f.FeePackage_ID = fp.Id
    LEFT JOIN dbo.FeeScale fs ON fs.Fee_Id = f.Id
    LEFT JOIN #AssetTypeMapping atm ON fs.AssetType = atm.AssetType -- from temp table, some data was NULL >> NULL mean 'Cash Call Account' in Asset Type
    WHERE 
        f.Name LIKE '%Management Fee%'
        AND fp.Name IN ('mySTART Fee Schedule', 'Craigs KS Fee Schedule', 'CIP Super Fee Schedule', 'superSTART Fee Schedule', 
                        'mySTART Staff Fee Schedule', 'Craigs KS Staff Fee Schedule', 'CIP Super Staff Fee Schedule', 
						'superSTART Staff Fee Schedule','superSTART Staff v2 Fee Schedule', 'mySTART Staff v2 Fee Schedule',
						-- added to handle edge cases, people tha tare staff in the past and not portfolio closed or pending closure or closing
						'mySTART Staff DO NOT USE','Craigs KS Staff DO NOT USE', 'superSTART Staff DO NOT USE',
						'mySTART Staff v2 DO NOT USE','CIP Super Staff DO NOT USE')
)
SELECT * INTO #RankedFeeScales FROM RankedFeeScales;


--Unit 4.3 : after getting the ranked range for End Value, i used COALESECE(LAG()) to create a Start value for each End Value, but the Null from End value need to be handle differently becasue in the ranking null is the smallest
-- Build CalculatedRanges temporary table
DROP TABLE IF EXISTS #CalculatedRanges;

;WITH CalculatedRanges AS (
    SELECT
        FeePackage_ID,
        FeePackageName,
        Normal_FeePackage_ID,
        Normal_FeePackageName,
        AuthorisedDate,
        CreatedDate,
        ActualisationFrequency,
        CalculationMethod,
        FeeName,
        AssetType,
        AssetTypeName,
        EndValue,
        AnnualisedFeeInPercentage,
        RowNum,
        COALESCE(LAG(EndValue) OVER (PARTITION BY FeePackageName, AssetTypeName ORDER BY RowNum), 0) -- lag mean moving one row below in the logical set
		AS StartValue, 
		-- this step is to move the End Value One row down by partition, when when there is a frist Null value occur we repalce them into 0.
        ROW_NUMBER() OVER (PARTITION BY FeePackageName, AssetTypeName ORDER BY RowNum) AS RowNum2 -- RowNum2 is just to provide a easy to see number while testing the code
    FROM #RankedFeeScales
)
SELECT * INTO #CalculatedRanges FROM CalculatedRanges;

--Unit 4.4:
-- Build FeeScheduleWithPercentage temporary table, finalised the table and handle some null error for the start value
DROP TABLE IF EXISTS #FeeScheduleWithPercentage;

;WITH FeeScheduleWithPercentage AS 
(SELECT
    FeePackage_ID,
    FeePackageName,
    Normal_FeePackage_ID,
    Normal_FeePackageName,
    AuthorisedDate,
    CreatedDate,
    ActualisationFrequency,
    CalculationMethod,
    FeeName,
    AssetType,
    AssetTypeName,
    CASE 
        WHEN EndValue IS NULL AND AssetTypeName = 'Unitised' THEN 0
        WHEN EndValue IS NULL THEN (SELECT MAX(EndValue) FROM #RankedFeeScales WHERE FeePackageName = cr.FeePackageName AND AssetTypeName = cr.AssetTypeName) 
		-- to reselect the startvalue as part of the no upper bound Scenario eg. 2.5mil and above i don't think a lot of people could reach this but it is helpful
        ELSE StartValue 
    END AS StartValue,
	-- this case when is to handle when null mean no upper bound in the end value but the coalesece turn it intn 0 in the previous step
    EndValue,
    AnnualisedFeeInPercentage
FROM #CalculatedRanges cr
)
SELECT * INTO #FeeScheduleWithPercentage FROM FeeScheduleWithPercentage;


--Unit 5 : this is to get the data for each date ValuationNZD  By Portfolio and by Asset Type >> this is important for the Asset type Percentage feee applied calculation
-- Populate TempValuationNZD temporary table
DROP TABLE IF EXISTS #TempValuationNZD;

;WITH TempValuationNZD AS (
    SELECT 
        p.id AS Portfolio_ID,
        p.PortfolioReference AS ClientCode,
        p.PortfolioName AS ClientName,

		-- newly added 
		ps.code AS PortfolioStatus,
		p.PortfolioClosedDate AS PortfolioClosedDate,

		--

        pfp.FeePackage_Id,

        fp.Name AS FeePackageName,

        CASE 
            WHEN fp.Id = 43 THEN 42
			WHEN fp.Id = 10 THEN 42--added the DO NOT USE situation

            WHEN fp.Id = 40 THEN 38
			WHEN fp.Id = 9 THEN 38--added the DO NOT USE situation

            WHEN fp.Id = 35 THEN 31
			WHEN fp.Id = 36 THEN 31-- added the v2 situation
			WHEN fp.Id = 8 THEN 31--added the DO NOT USE situation
			WHEN fp.Id = 22 THEN 31--added the DO NOT USE situation

            WHEN fp.Id = 50 THEN 45
			WHEN fp.Id = 11 THEN 45 --added the DO NOT USE situation
			WHEN fp.Id = 51 THEN 45 -- added the v2 situation
			

            ELSE fp.Id
        END AS Normal_FeePackage_ID,
		-- to reassign package id from staff to a normal package, Why? because we want to see if a staff not a staff how much we are going to Charge them
        CASE 
            WHEN fp.Name = 'CIP Super Staff Fee Schedule' THEN 'CIP Super Fee Schedule'
			WHEN fp.Name = 'CIP Super Staff DO NOT USE' THEN 'CIP Super Fee Schedule'--added the DO NOT USE situation

            WHEN fp.Name = 'Craigs KS Staff Fee Schedule' THEN 'Craigs KS Fee Schedule'
			WHEN fp.Name = 'Craigs KS Staff DO NOT USE' THEN 'Craigs KS Fee Schedule'--added the DO NOT USE situation

            WHEN fp.Name = 'mySTART Staff Fee Schedule' THEN 'mySTART Fee Schedule'
			WHEN fp.Name = 'mySTART Staff v2 Fee Schedule' THEN 'mySTART Fee Schedule' --added the v2 situation
			WHEN fp.Name = 'mySTART Staff DO NOT USE' THEN 'mySTART Fee Schedule' --added the DO NOT USE situation
			WHEN fp.Name = 'mySTART Staff v2 DO NOT USE' THEN 'mySTART Fee Schedule'--added the DO NOT USE situation

            WHEN fp.Name = 'superSTART Staff Fee Schedule' THEN 'superSTART Fee Schedule'
			WHEN fp.Name = 'superSTART Staff DO NOT USE' THEN 'superSTART Fee Schedule' --added the DO NOT USE situation
			WHEN fp.Name = 'superSTART Staff v2 Fee Schedule' THEN 'superSTART Fee Schedule' --added the v2 situation

            ELSE fp.Name
        END AS Normal_FeePackageName,
		-- this is to swap the original staff packages into a normal packages so we could calcualte the differences

        fp.AuthorisedDate, -- this date told us when the fee packages got activated
        pr.Type AS StaffType,
        ob.BranchName AS Branch,
        oac.CommissionCode AS AdvisorCode, 
        CASE a.ProductType
            WHEN 'OPT' THEN 'Option'
            WHEN 'FIX' THEN 'Term Deposits & Debentures'
            WHEN 'BB' THEN 'Bank Bill'
            WHEN 'UTR' THEN 'Unitised'
            WHEN 'SHA' THEN 'Shares'
            WHEN 'GOV' THEN 'Government Bonds'
            WHEN 'BND' THEN 'Bonds & Notes'
            WHEN 'IBD' THEN 'Insurance Bond'
            WHEN 'CAS' THEN 'Cash Asset'
            WHEN 'FWD' THEN 'Forward'
            ELSE 'Cash Call Account'
        END AS AssetType,
		FORMAT(pvh.ValuationAsAtDate, 'yyyy-MM-dd') AS ValuationAsAtDate,
        FORMAT(pvh.CalculatedDate, 'yyyy-MM-dd') AS CalculatedDate,
        (pvhd.ValuationRootAmount) as ValuationNZD 
    FROM 
	-- this part is to bring in the historical valuation by Asset and by Portfolio
	PortfolioValuationHistoryDetail pvhd
    LEFT JOIN asset a ON a.id = pvhd.Asset_ID
    JOIN currency c ON c.id = pvhd.Currency_Id
    JOIN portfoliovaluationhistoryheader pvh ON pvhd.PortfolioValuationHistoryHeader_Id = pvh.id
    JOIN portfolio p ON p.id = pvh.Portfolio_id
	JOIN PortfolioStatus ps ON p.STATUS = ps.Id -- to bring in the portfolio actual status

	---- this aprt is to bring in the FeePackage_ID for each portfolio for later join with the #FeeScheduleWithPercentage (this table similar to the feeschedule PDF files)
    JOIN PortfolioFeePackage pfp ON pfp.Portfolio_ID = p.Id
    JOIN FeePackage fp ON fp.Id = pfp.FeePackage_Id

	----- this part is to bring int the Branch , advisort, whic htype of staff details
    JOIN dbo.OrganisationBranch ob ON ob.Id = p.OrganisationBranch_Id
    JOIN dbo.OrganisationAdvisorCode oac ON oac.Id = p.OrganisationAdvisorCode_Id
    JOIN Entity e ON e.Id = p.Client_Id
    JOIN #PrescribedPerson pr ON pr.Id = e.PrescribedPersonType -- joining on temp table
    WHERE 
	1=1
	AND fp.Name IN ('mySTART Fee Schedule', 'Craigs KS Fee Schedule', 'CIP Super Fee Schedule', 'superSTART Fee Schedule', 
                        'mySTART Staff Fee Schedule', 'Craigs KS Staff Fee Schedule', 'CIP Super Staff Fee Schedule', 
						'superSTART Staff Fee Schedule','superSTART Staff v2 Fee Schedule', 'mySTART Staff v2 Fee Schedule',
						 --added to handle edge cases, people tha tare staff in the past and not portfolio closed or pending closure or closing
						'mySTART Staff DO NOT USE','Craigs KS Staff DO NOT USE', 'superSTART Staff DO NOT USE',
						'mySTART Staff v2 DO NOT USE','CIP Super Staff DO NOT USE')

		--AND (f.Name LIKE '%Management Fee Staff%' OR  f.Name LIKE '%Management Fee  - Staff%')
        --AND pr.Id NOT IN (0, 7) -- this is to filtered out non staff becasue we only care about staff related members
		--AND pfp.Status = 450
        --AND fp.DeactivatedDate IS NULL
        AND (p.PortfolioReference = @PortfolioID OR @PortfolioID IS NULL)
        AND pvh.ValuationasAtDate BETWEEN @StartDate AND @EndDate
)
SELECT * INTO #TempValuationNZD FROM TempValuationNZD;


-- Troubles Shoot: disccrepoencys up to unit 5
-->> i found out at the Correct SSRS report called -- valuations summed by AssetType >> sum(pvhd.ValuationRootAmount) as ValuationNZD there is Aggreagation here, 
--becasue one date it could have multiple valuation, like in 01/06/2024 it could have multiple valuation like 2000, 30000, 500000, each so if not aggreagated it might casue error.
--Select * FROM #TempValuationNZD


---Unit 5.1 Added this temp table to Aggreagre all the ValuationNZD to a Date level (That's becasue in one date ther might be multple asset traded, so got multiple Valuacte NZD)
IF OBJECT_ID('tempdb..#PortfolioValuationByAssetType') IS NOT NULL DROP TABLE #PortfolioValuationByAssetType;

SELECT
    Portfolio_ID,
    ClientCode,
    ClientName,
	--
	PortfolioStatus,
	PortfolioClosedDate,
	--
    StaffType,
    Branch,
    AdvisorCode,
    AssetType,

	FeePackage_Id,
	FeePackageName,

    Normal_FeePackage_ID,
    Normal_FeePackageName,
	ValuationAsAtDate,
    CalculatedDate,
    SUM(ValuationNZD) AS ValuationNZD
INTO #PortfolioValuationByAssetType
FROM #TempValuationNZD
GROUP BY 
    Portfolio_ID,
    ClientCode,
    ClientName,
	PortfolioStatus,
	PortfolioClosedDate,
    StaffType,
    Branch,
    AdvisorCode,
    AssetType,
	FeePackage_Id,
	FeePackageName,
    Normal_FeePackage_ID,
    Normal_FeePackageName,
	ValuationAsAtDate,
    CalculatedDate;


--Unit 6:
-- Calculate Normal Management Fee when a staff not a staff 
-- This CTE calculates how much management fee a staff member would pay under a normal fee schedule
IF OBJECT_ID('tempdb..#FinalManagementFees') IS NOT NULL DROP TABLE #FinalManagementFees;

-- wrap the query in CTE for better handling
;WITH FinalManagementFees AS (
    SELECT 
        tvn.Portfolio_ID,
        tvn.ClientCode,
        tvn.ClientName,
		tvn.PortfolioStatus,
		tvn.PortfolioClosedDate,
        tvn.StaffType,
        tvn.Branch,
        tvn.AdvisorCode,
        tvn.AssetType,
        tvn.ValuationAsAtDate,
        tvn.ValuationNZD,
		tvn.FeePackage_Id,
	    tvn.FeePackageName,
        tvn.Normal_FeePackage_ID,
        tvn.Normal_FeePackageName,
        fswp.StartValue,
        fswp.EndValue,
        fswp.AnnualisedFeeInPercentage,

		--- this is the importantant part , for example jackson have 1000nzd shares, then it will be search it betweeen the range ,
		--get the AnnualisedFeeInPercentage / 100 and then / 365 Becasue this is a Annualsied fee and now we are at a ValuationAsAtDate level. 
		--So (((1000 * 1.25)/100)/365) would be the math representation of the fee
		CASE
        -- Condition 1: package name with "Do Not Use" with closed date not null and status not Active, for scenario that opened in the past but not no longeractive, end user want  thsi data for some reasons
        WHEN tvn.FeePackageName LIKE '%Do Not Use%' AND tvn.PortfolioClosedDate IS NOT NULL AND tvn.PortfolioStatus <> 'Active' THEN
            CASE
                -- Calculate normally before the closed date
                WHEN @StartDate < tvn.PortfolioClosedDate AND @EndDate > tvn.PortfolioClosedDate THEN
                    CASE
                        WHEN tvn.AssetType = 'Shares' AND tvn.Normal_FeePackageName IN ('Craigs KS Fee Schedule', 'CIP Super Fee Schedule', 'superSTART Fee Schedule', 'mySTART Fee Schedule') THEN
                            CASE
                                WHEN tvn.ValuationNZD > fswp.StartValue AND (tvn.ValuationNZD <= fswp.EndValue OR fswp.EndValue IS NULL) THEN
                                    ((CASE
                                        WHEN tvn.ValuationNZD < fswp.EndValue THEN tvn.ValuationNZD
                                        ELSE fswp.EndValue 
                                    END) - fswp.StartValue) * (fswp.AnnualisedFeeInPercentage / 100 / 365)
                                WHEN tvn.ValuationNZD > fswp.EndValue THEN
                                    (fswp.EndValue - fswp.StartValue) * (fswp.AnnualisedFeeInPercentage / 100 / 365)
                                ELSE
                                    0
                            END
                        WHEN tvn.AssetType = 'Cash Call Account' THEN
                            CASE 
                                WHEN tvn.ValuationNZD > 10000 THEN 
                                    CAST((tvn.ValuationNZD - 10000) * (fswp.AnnualisedFeeInPercentage / 100) / 365 AS DECIMAL(20, 10))
                                ELSE
                                    0
                            END
                        WHEN tvn.AssetType = 'Unitised' THEN
                            CASE 
                                WHEN tvn.ValuationNZD > 0 THEN 
                                    CAST(tvn.ValuationNZD * (fswp.AnnualisedFeeInPercentage / 100) / 365 AS DECIMAL(20, 10))
                                ELSE 
                                    0
                            END
                        ELSE 
                            0
                    END
                ELSE 
                    0 -- Set fee to 0 after the closed date
            END
        -- Condition 2: "Do Not Use" with closed date is null and status is not "Closed" >> for scenario that in DO not Use package but still open somehow
       -- for this condition just stick to the normal calculation
        -- Condition 3: logic for active portfolios with thenormal package name
        ELSE
            CASE
                WHEN tvn.AssetType = 'Shares' AND tvn.Normal_FeePackageName IN ('Craigs KS Fee Schedule', 'CIP Super Fee Schedule', 'superSTART Fee Schedule', 'mySTART Fee Schedule') THEN
                    CASE
                        WHEN tvn.ValuationNZD > fswp.StartValue AND (tvn.ValuationNZD <= fswp.EndValue OR fswp.EndValue IS NULL) THEN
                            ((CASE
                                WHEN tvn.ValuationNZD < fswp.EndValue THEN tvn.ValuationNZD
                                ELSE fswp.EndValue 
                            END) - fswp.StartValue) * (fswp.AnnualisedFeeInPercentage / 100 / 365)
                        WHEN tvn.ValuationNZD > fswp.EndValue THEN
                            (fswp.EndValue - fswp.StartValue) * (fswp.AnnualisedFeeInPercentage / 100 / 365)
                        ELSE
                            0
                    END
                WHEN tvn.AssetType = 'Cash Call Account' THEN
                    CASE 
                        WHEN tvn.ValuationNZD > 10000 THEN 
                            CAST((tvn.ValuationNZD - 10000) * (fswp.AnnualisedFeeInPercentage / 100) / 365 AS DECIMAL(20, 10))
                        ELSE
                            0
                    END
                WHEN tvn.AssetType = 'Unitised' THEN
                    CASE 
                        WHEN tvn.ValuationNZD > 0 THEN 
                            CAST(tvn.ValuationNZD * (fswp.AnnualisedFeeInPercentage / 100) / 365 AS DECIMAL(20, 10))
                        ELSE 
                            0
                    END
                ELSE 
                    0
            END
    END AS NormalManagementFee

    FROM #PortfolioValuationByAssetType tvn
    JOIN #FeeScheduleWithPercentage fswp 
        ON tvn.Normal_FeePackage_ID = fswp.FeePackage_ID  
        AND tvn.AssetType = fswp.AssetTypeName
)
SELECT
    Portfolio_ID,
    ClientCode,
    ClientName,
	--
	PortfolioStatus,
	PortfolioClosedDate,
	--
    StaffType,
    Branch,
    AdvisorCode,
    --AssetType,
	--ValuationAsAtDate, --these columns are to go down to the date level to trouble shoot if have issues
	--ValuationNZD,
	--AnnualisedFeeInPercentage,
    --Normal_FeePackage_ID,
    --Normal_FeePackageName,
    SUM(NormalManagementFee) AS NormalManagementFee
INTO #FinalNormalManagementFees
FROM FinalManagementFees
GROUP BY 
    Portfolio_ID,
    ClientCode,
    ClientName,

	PortfolioStatus,
	PortfolioClosedDate,
    StaffType,
    Branch,
    AdvisorCode
 
-- Select final results
--SELECT * FROM #FinalNormalManagementFees;


--Unit 7: this unit failed due to the staff manamagement fee set don't have an asset type, 
--when merged with The normal fee set and it is introducing duplicate for each asset type
--so the full amount of asset type would appear twice in the output causing confusion

---- Merge Staff Management Fee with Normal Management Fee together on Client Code (Portfolio Level , One client code = 1 Portfolio)
SELECT 
fsmf.ClientCode,
fsmf.ClientName,
--
fsmf.PortfolioStatus,
fsmf.PortfolioClosedDate,
--
fsmf.StaffType,
fsmf.Branch,
fsmf.AdvisorCode,
fsmf.FeePackage_Id,
fsmf.FeeName,
fsmf.FeePackageName,
fsmf.TransactionDescription,
CAST(ROUND(fsmf.FinalStaffManagementFee, 5) AS DECIMAL(10, 5)) AS FinalStaffManagementFee,
CAST(ROUND(fnmf.NormalManagementFee, 5) AS DECIMAL(10, 5)) AS NormalManagementFee

FROM 
#FinalStaffManagementFee fsmf
JOIN #FinalNormalManagementFees fnmf
ON fnmf.ClientCode = fsmf.ClientCode

-- FOR SSRS Parameters
WHERE 
1=1
AND fsmf.Branch IN (@Branch)
AND fsmf.FeePackageName IN (@FeePackage)
AND fsmf.PortfolioStatus IN (@PortfolioStatus)

-- Drop temporary tables after use
-- DROP TABLE #AssetTypeMapping;
-- DROP TABLE #RankedFeeScales;
-- DROP TABLE #CalculatedRanges;
-- DROP TABLE #FeeScheduleWithPercentage;
-- DROP TABLE #TempValuationNZD;
-- DROP TABLE #PrescribedPerson;
-- DROP TABLE #StaffManagementFee;
-- DROP TABLE #PortfolioValuationByAssetType;
-- DROP TABLE #FinalStaffManagementFee;
-- DROP TABLE #FinalNormalManagementFees;
