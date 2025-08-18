--Building Step 7: Pivoting Data and Applying Mapping




----Step 7.1 Separate Data for CRSOnly and FATCAOnly Reporting, No More Overlapiing
--	--JF obervered One individual have 3 TINs, and one TIN is US TIN which need to report for FATCA.
----For CRS Reporting: Do not include the US TIN (TIN3). Only include TIN1 and TIN2 for CRS reporting.
----For FATCA Reporting: Include only the US TIN (TIN3) for FATCA reporting.

-- Drop temporary tables if they exist
IF OBJECT_ID('tempdb..#CRSOnlyData') IS NOT NULL DROP TABLE #CRSOnlyData;
IF OBJECT_ID('tempdb..#FATCAOnlyData') IS NOT NULL DROP TABLE #FATCAOnlyData;

-- Filter data for only CRS Reporting (excluding US TINs), remvoe the OVelapping and remvoe the ambuguity>> why i am not filtering in step 6.
-- step 6 is way too complex is not the right palce to handle the ovelapping
SELECT
    *
INTO #CRSOnlyData  -- this is to handle people tha tovelapping with multiple TINS
FROM [SQLUAT].[DataServices].FATCA.Stage_crmdatafatcacrs_jf 
WHERE
    Regime IN ('CRS', 'FATCA_CRS') 
    AND Ind_TaxCodeCountryISO <> 'USA' -- this is to make sure fro CRS we only report NON US person
	

-- Filter data for only FATCA Reporting (including only US TINs), remvoe the OVelapping and remvoe the ambuguity
SELECT
    *
INTO #FATCAOnlyData -- this is to handle people tha tovelapping with multiple TINS
FROM [SQLUAT].[DataServices].FATCA.Stage_crmdatafatcacrs_jf 
WHERE
    Regime IN ('FATCA', 'FATCA_CRS')  
	AND Ind_TaxCodeCountryISO = 'USA'; -- this is to make sure for FATCA we only report actual US person












-- Step 7.2  Assign row numbers to TINs per individual/entity and portfolio by the correct Partioon by TO  CRS SET  (STEP 7.2 is the CRS onl ydata)
-- Drop temporary tables if they exist
IF OBJECT_ID('tempdb..#CRSDistinctTINs') IS NOT NULL DROP TABLE #CRSDistinctTINs;
IF OBJECT_ID('tempdb..#CRSTINRowNums') IS NOT NULL DROP TABLE #CRSTINRowNums;
IF OBJECT_ID('tempdb..#CRSDataWithRowNum') IS NOT NULL DROP TABLE #CRSDataWithRowNum;

-- Create a distinct list of TINs per individual by Tax country and TIN, so logically One indiviudals could only have one IndividualId, that could have Multple Ind_TaxCodeCountryISO and Multiple cip_Identifications
SELECT DISTINCT
    cdfc.IndividualId,
    cdfc.Ind_TaxCodeCountryISO,
    cdfc.cip_Identification
INTO #CRSDistinctTINs
FROM
    #CRSOnlyData cdfc;

-- Assign TINRowNum using DENSE_RANK() >> why using dense Rank here it is becasue sometime IndividualIDTypeName is NULL due to data Error
--Use DENSE_RANK() to deal with Ties
SELECT
    dt.*,
    DENSE_RANK() OVER (
        PARTITION BY dt.IndividualId
        ORDER BY dt.Ind_TaxCodeCountryISO, dt.cip_Identification
    ) AS TINRowNum
INTO #CRSTINRowNums
FROM #CRSDistinctTINs dt;
-- using the #DistinctTINs dt Join back to the original data to create the correct partition
SELECT
    cdfc.*,
    trn.TINRowNum
INTO #CRSDataWithRowNum
FROM
    #CRSOnlyData cdfc
LEFT JOIN #CRSTINRowNums trn ON
    cdfc.IndividualId = trn.IndividualId AND
    cdfc.Ind_TaxCodeCountryISO = trn.Ind_TaxCodeCountryISO AND
    cdfc.cip_Identification = trn.cip_Identification


-- Step 7.3  Assign row numbers to TINs per individual/entity and portfolio by the correct Partioon by TO FATCA SET (Step 7.3 is the FATCA data)
IF OBJECT_ID('tempdb..#FATCADistinctTINs') IS NOT NULL DROP TABLE #FATCADistinctTINs;
IF OBJECT_ID('tempdb..#FATCATINRowNums') IS NOT NULL DROP TABLE #FATCATINRowNums;
IF OBJECT_ID('tempdb..#FATCADataWithRowNum') IS NOT NULL DROP TABLE #FATCADataWithRowNum;

-- Create a distinct list of TINs per individual by Tax country and TIN, so logically One indiviudals could only have one IndividualId, that could have Multple Ind_TaxCodeCountryISO and Multiple cip_Identifications
SELECT DISTINCT
    cdfc.IndividualId,
    cdfc.Ind_TaxCodeCountryISO,
    cdfc.cip_Identification
INTO #FATCADistinctTINs
FROM
    #FATCAOnlyData cdfc;

-- Assign TINRowNum using DENSE_RANK() >> why using dense Rank here it is becasue sometime IndividualIDTypeName is NULL due to data Error
--Use DENSE_RANK() to deal with Ties
SELECT
    dt.*,
    DENSE_RANK() OVER (
        PARTITION BY dt.IndividualId
        ORDER BY dt.Ind_TaxCodeCountryISO, dt.cip_Identification
    ) AS TINRowNum
INTO #FATCATINRowNums
FROM #FATCADistinctTINs dt;
-- using the #DistinctTINs dt Join back to the original data to create the correct partition
SELECT
    cdfc.*,
    trn.TINRowNum
INTO #FATCADataWithRowNum
FROM
    #FATCAOnlyData cdfc
LEFT JOIN #FATCATINRowNums trn ON
    cdfc.IndividualId = trn.IndividualId AND
    cdfc.Ind_TaxCodeCountryISO = trn.Ind_TaxCodeCountryISO AND
    cdfc.cip_Identification = trn.cip_Identification

---- Check the TINs have the correct partitions, yes correct now
--SELECT 
--    ed.EntityName, 
--    ed.IndividualName,
--    ed.PortfolioNo, 
--    ed.PortfolioServiceLevelName,
--    ed.Ind_TaxCodeCountryISO,
--    ed.cip_Identification,
--    ed.IndividualIDTypeName,
--    ed.TINRowNum
----FROM #CRSOnlyData ed
--FROM #FATCAOnlyData ed
--WHERE 1=1
-- --AND ed.IndividualId = '5B3EF7D2-E473-EF11-A310-00224893A091' -- this isfor testing 'Single TIN Individual'
--AND ed.AccountType = 'Multiple TINs Individual'
----AND ed.TINRowNum =3
----AND ed.Regime = 'CRS'
----AND ed.IndividualIDTypeName IS NULL -- indication of data error CRM missing data casuing the TIN partion having error, whic hwould casuse issues down the line, this error had be fixed using the Dese Rank()techniqes




-- Step 7.4: Pivot TINs into columns from row base into column base, for CRS set
--eg. sarah is Citienzen of US and singproe and France, so she got 3 TINs.
-- i seperate Sarah into two set , one set is only for fatca, one set is only fro CRS , FATC >> she would get one US tin, CRS she would get two TINs
--Now for these 2 tins it is row by by row (row 1, row 2), and after the slefjoin It cbeome TIN1 in column 1 , TIN2 in column2 etc.
--WHY?? becasue Anease the original develoepr do it this way

-- Drop the final temporary table if it exists
IF OBJECT_ID('tempdb..#CRSPivotedData') IS NOT NULL DROP TABLE #CRSPivotedData;

SELECT
    -- Select unique individual/entity details
	b.AccountType,
    b.AccountID,
	b.IndividualId,

	--Indivduals Detaisl info here
	b.IndividualName,


	b.FirstName,
	b.MiddleName,
	b.LastName,

	--cotmnacts details , where di thet live
	b.Tel1,
	b.Tel2,
	b.Tel3,
	b.ResidentialAddressLine1,
	b.ResidentialAddressLine2,
	b.ResidentialAddressLine3,
	b.ResidentialCity,
	b.ResidentialPostalCode,
	b.PostalAddressLine1,
	b.PostalAddressLine2,
	b.PostalAddressLine3,
	b.PostalCity,
	b.PostalPostCode,

	-- Tax related details 
	b.TrustCountry,
	b.OrgPrimaryTaxDomicile,
	b.ResidentialCountry1,
	b.PostalCountry2,
	b.RegisteredOfficeCountry3,
	b.ResidentialCountry2,
	b.CountryofResidence,
	b.Country2ofResidence,
	b.Country3ofResidence,
	b.CountryofCitizenship,
	b.CountryofTaxResidency,

	b.EntityName,
	b.EntityID,
	b.TaxRegime,

	-- Entity Level TINS Details 
	b.EntityTIN,
	b.EntityIDTypeName,
	b.EntityCountryJurisdictionName,
	b.EntityTaxCodeCountryISOShort,
	b.EntityTaxCodeCountryName,
	
	
    -- Pivoted INDIVIduakl level TINs and corresponding Tax Countries, i only see up to TIN 3, CRS is up to 2 tins, FATCA should only have 1 TINS

	--b.EntityTaxCodeCountryISOShort, -- The shhort ISO code fro the tax country
 --   b.Ind_TaxCodeCountryISOShort -- -- The shhort ISO code fro the tax country

    TIN1.cip_Identification AS TIN1,
    TIN1.IndividualIDTypeName AS IndividualIDTypeName1,
    TIN1.Ind_TaxCodeCountryISOShort AS TaxCountry1, -- this had becoem the short code

    TIN2.cip_Identification AS TIN2,
    TIN2.IndividualIDTypeName AS IndividualIDTypeName2,
    CASE
        WHEN TIN2.Ind_TaxCodeCountryISOShort = TIN1.Ind_TaxCodeCountryISOShort THEN NULL
        ELSE TIN2.Ind_TaxCodeCountryISOShort
    END AS TaxCountry2,
    TIN3.cip_Identification AS TIN3,
    TIN3.IndividualIDTypeName AS IndividualIDTypeName3,
    CASE
        WHEN TIN3.Ind_TaxCodeCountryISOShort IN (TIN1.Ind_TaxCodeCountryISOShort, TIN2.Ind_TaxCodeCountryISOShort) THEN NULL
        ELSE TIN3.Ind_TaxCodeCountryISOShort
    END AS TaxCountry3,
    TIN4.cip_Identification AS TIN4,
    TIN4.IndividualIDTypeName AS IndividualIDTypeName4,
    CASE
        WHEN TIN4.Ind_TaxCodeCountryISOShort IN (TIN1.Ind_TaxCodeCountryISOShort, TIN2.Ind_TaxCodeCountryISOShort, TIN3.Ind_TaxCodeCountryISOShort) THEN NULL
        ELSE TIN4.Ind_TaxCodeCountryISOShort
    END AS TaxCountry4,
    TIN5.cip_Identification AS TIN5,
    TIN5.IndividualIDTypeName AS IndividualIDTypeName5,
    CASE
        WHEN TIN5.Ind_TaxCodeCountryISOShort IN (TIN1.Ind_TaxCodeCountryISOShort, TIN2.Ind_TaxCodeCountryISOShort, TIN3.Ind_TaxCodeCountryISOShort, TIN4.Ind_TaxCodeCountryISOShort) THEN NULL
        ELSE TIN5.Ind_TaxCodeCountryISOShort
    END AS TaxCountry5,

	---Portfolio services details
	b.dsl_portfolioid,
	b.PortfolioNo,
	b.PortfolioServiceLevelName,

	
	-- roles info
	b.dsl_RoleTypeIdName,
	b.dsl_BeneficialOwner,
	b.dsl_BeneficiaryOwnership,
	b.SubstantialControllingInterest,
	b.dsl_applicant,
	b.dsl_Authorised,

	-- TE type 
	b.TradingEntityType,

	-- Portfolio and the FATCA CRS sectios INFO
	b.PortfolioServiceStatus,
	b.CRSCert,
	b.PassiveActive,

	--date info for the Portfolio services
	b.dsl_inceptiondate,
	b.dsl_CloseDate,
	b.CountryofBirthIdName,
	b.USCitizensforTaxPurposes_acc,
	b.USCitizensforTaxPurposes_ind,
	b.DOB,
	b.ClosureDate,
	b.TownCityofBirth,

	-- this is the remapped falgs fro the reporting regime
	b.Regime,


	--- bring in the Controlling person Type And desction
		cp.[CP Type],
		cp.[CP Value],


   -- Bring in the ISO country code from step 6.0
    b.[Res Country Code], -- 'XX' indicates missing ISO code

    
    b.[Postal Country Code], -- 'XX' indicates missing ISO code

   
    b.[Country of Birth] -- 'XX' indicates missing ISO code

	

INTO #CRSPivotedData   
FROM
--use the step 7.1 table as the mai nbase table
    #CRSDataWithRowNum b 
---left join to [SQLCIP].[DataServices].[dbo].[crs_ControllingPersonTypeMapping] to get the correct CRS type, the mappin gtabel might be outdated, need to check with actual requirements
	LEFT JOIN [SQLUAT].[DataServices].[dbo].[crs_ControllingPersonTypeMapping] cp ON cp.[Role Type] COLLATE DATABASE_DEFAULT = b.dsl_RoleTypeIdName COLLATE DATABASE_DEFAULT
                                                                                               AND cp.[TE Type] COLLATE DATABASE_DEFAULT = b.[TradingEntityType] COLLATE DATABASE_DEFAULT
-- Join for TIN1 (TINRowNum = 1)
LEFT JOIN #CRSDataWithRowNum TIN1
    ON b.AccountID = TIN1.AccountID
    AND b.PortfolioNo = TIN1.PortfolioNo
    AND b.PortfolioServiceLevelName = TIN1.PortfolioServiceLevelName
    AND b.IndividualId = TIN1.IndividualId
    AND TIN1.TINRowNum = 1
-- Join for TIN2 (TINRowNum = 2)
LEFT JOIN #CRSDataWithRowNum TIN2
    ON b.AccountID = TIN2.AccountID
    AND b.PortfolioNo = TIN2.PortfolioNo
    AND b.PortfolioServiceLevelName = TIN2.PortfolioServiceLevelName
    AND b.IndividualId = TIN2.IndividualId
    AND TIN2.TINRowNum = 2
-- Join for TIN3 (TINRowNum = 3)  -- this is the higest number of TINs i seen, mean oen individual have 3 TINs
LEFT JOIN #CRSDataWithRowNum TIN3
    ON b.AccountID = TIN3.AccountID
    AND b.PortfolioNo = TIN3.PortfolioNo
    AND b.PortfolioServiceLevelName = TIN3.PortfolioServiceLevelName
    AND b.IndividualId = TIN3.IndividualId
    AND TIN3.TINRowNum = 3
	--commeted TIN 4 and 5 out becasue there are no people have more than 3 tins in our currect datasets
-- Join for TIN4 (TINRowNum = 4)
LEFT JOIN #CRSDataWithRowNum TIN4
    ON b.AccountID = TIN4.AccountID
    AND b.PortfolioNo = TIN4.PortfolioNo
    AND b.PortfolioServiceLevelName = TIN4.PortfolioServiceLevelName
    AND b.IndividualId = TIN4.IndividualId
    AND TIN4.TINRowNum = 4
-- Join for TIN5 (TINRowNum = 5)
LEFT JOIN #CRSDataWithRowNum TIN5
    ON b.AccountID = TIN5.AccountID
    AND b.PortfolioNo = TIN5.PortfolioNo
    AND b.PortfolioServiceLevelName = TIN5.PortfolioServiceLevelName
    AND b.IndividualId = TIN5.IndividualId
    AND TIN5.TINRowNum = 5
WHERE
    b.TINRowNum = 1; -- Select one row per individual/entity per portfolio



------	---- Check how many Country at most they have TINs for CRS SET
--	Select *
--	FROM
--	#CRSPivotedData
--	WHERE 1=1 
--	--AND AccountType ='Layered Entity'
--	--AND TIN1 IS NULL
--	--AND IndividualName = 'Catherine Marie Rey-Herme Cousins'
--	AND TIN2 IS NOT NULL -- from my observation TIN 3 is the deepest level -- Stella Jane Golf



-- Output FATCA.Stage_CRSPivotedData_jf : Create the Staging Table
--  Create or Truncate the Staging Table for CRS pivoted data set

-- Drop the staging table if it exists
IF OBJECT_ID('FATCA.Stage_CRSPivotedData_jf', 'U') IS NOT NULL
BEGIN
    DROP TABLE FATCA.Stage_CRSPivotedData_jf;
END

-- Create the staging table with the same schema as #CRSPivotedData but no data
SELECT TOP 0 *
INTO FATCA.Stage_CRSPivotedData_jf
FROM #CRSPivotedData;

-- Insert Data into the Staging Table
INSERT INTO FATCA.Stage_CRSPivotedData_jf
SELECT *
FROM #CRSPivotedData;
 -- 4525 Rows


-------------
-- Step 7.5: Pivot TINs into columns from row base into column base, for FATCA only set (there should be only one TIN in this set)
--eg. sarah is Citienzen of US and singproe and France, so she got 3 TINs.
-- i seperate Sarah into two set , one set is only for fatca, one set is only fro CRS , FATC >> she would get one US tin, CRS she would get two TINs
--Now for these one tins it is row by by row (row 1), and after the slefjoin It beome TIN1 in column 1 , TIN2 should not have any value , same fro TIN 3
--WHY?? becasue Anease the original develoepr do it this way

-- Drop the final temporary table if it exists
IF OBJECT_ID('tempdb..#FATCAPivotedData') IS NOT NULL DROP TABLE #FATCAPivotedData;

SELECT
    -- Select unique individual/entity details
	b.AccountType,
    b.AccountID,
	b.IndividualId,

	--Indivduals Detaisl info here
	b.IndividualName,


	b.FirstName,
	b.MiddleName,
	b.LastName,

	--cotmnacts details , where di thet live
	b.Tel1,
	b.Tel2,
	b.Tel3,
	b.ResidentialAddressLine1,
	b.ResidentialAddressLine2,
	b.ResidentialAddressLine3,
	b.ResidentialCity,
	b.ResidentialPostalCode,
	b.PostalAddressLine1,
	b.PostalAddressLine2,
	b.PostalAddressLine3,
	b.PostalCity,
	b.PostalPostCode,

	-- Tax related details 
	b.TrustCountry,
	b.OrgPrimaryTaxDomicile,
	b.ResidentialCountry1,
	b.PostalCountry2,
	b.RegisteredOfficeCountry3,
	b.ResidentialCountry2,
	b.CountryofResidence,
	b.Country2ofResidence,
	b.Country3ofResidence,
	b.CountryofCitizenship,
	b.CountryofTaxResidency,

	b.EntityName,
	b.EntityID,
	b.TaxRegime,

	-- Entity Level TINS Details 
	b.EntityTIN,
	b.EntityIDTypeName,
	b.EntityCountryJurisdictionName,
	b.EntityTaxCodeCountryISOShort,
	b.EntityTaxCodeCountryName,
	
	
    -- Pivoted INDIVIduakl level TINs and corresponding Tax Countries, i only see up to TIN 3, CRS is up to 2 tins, FATCA should only have 1 TINS
    TIN1.cip_Identification AS TIN1,
    TIN1.IndividualIDTypeName AS IndividualIDTypeName1,
    TIN1.Ind_TaxCodeCountryISOShort AS TaxCountry1,

	---Portfolio services details
	b.dsl_portfolioid,
	b.PortfolioNo,
	b.PortfolioServiceLevelName,

	
	-- roles info
	b.dsl_RoleTypeIdName,
	b.dsl_BeneficialOwner,
	b.dsl_BeneficiaryOwnership,
	b.SubstantialControllingInterest,
	b.dsl_applicant,
	b.dsl_Authorised,

	-- TE type 
	b.TradingEntityType,

	-- Portfolio and the FATCA CRS sectios INFO
	b.PortfolioServiceStatus,
	b.CRSCert,
	b.PassiveActive,

	--date info for the Portfolio services
	b.dsl_inceptiondate,
	b.dsl_CloseDate,
	b.CountryofBirthIdName,
	b.USCitizensforTaxPurposes_acc,
	b.USCitizensforTaxPurposes_ind,
	b.DOB,
	b.ClosureDate,
	b.TownCityofBirth,

	-- this is the remapped falgs fro the reporting regime
	b.Regime,

	 -- Bring in the ISO country code from step 6.0
    b.[Res Country Code], -- 'XX' indicates missing ISO code

    
    b.[Postal Country Code], -- 'XX' indicates missing ISO code

   
    b.[Country of Birth] -- 'XX' indicates missing ISO code

INTO #FATCAPivotedData   
FROM
--use the step 7.1 table as the mai nbase table
    #FATCADataWithRowNum b 
-- Join for TIN1 (TINRowNum = 1)
LEFT JOIN #FATCADataWithRowNum TIN1
    ON b.AccountID = TIN1.AccountID
    AND b.PortfolioNo = TIN1.PortfolioNo
    AND b.PortfolioServiceLevelName = TIN1.PortfolioServiceLevelName
    AND b.IndividualId = TIN1.IndividualId
    AND TIN1.TINRowNum = 1
WHERE
    b.TINRowNum = 1; -- Select one row per individual/entity per portfolio



----	---- Check how many Country at most they have TINs for FATCA SET
--	Select *
--	FROM
--	#FATCAPivotedData
--	WHERE 1=1 
--	--AND AccountType ='Layered Entity'
--	--AND TIN1 IS NULL
--	--AND IndividualName = 'Catherine Marie Rey-Herme Cousins'
--	AND TIN2 IS NOT NULL -- from my observation TIN 3 is the deepest level -- Stella Jane Golf



-- Output FATCA.Stage_FATCAPivotedData_jf : Create the Staging Table
--  Create or Truncate the Staging Table for FATCA pivoted data set

-- Drop the staging table if it exists
IF OBJECT_ID('FATCA.Stage_FATCAPivotedData_jf', 'U') IS NOT NULL
BEGIN
    DROP TABLE FATCA.Stage_FATCAPivotedData_jf;
END

-- Create the staging table with the same schema as ##crmdatafatcacrs but no data
SELECT TOP 0 *
INTO FATCA.Stage_FATCAPivotedData_jf
FROM #FATCAPivotedData;

-- : Insert Data into the Staging Table
INSERT INTO FATCA.Stage_FATCAPivotedData_jf
SELECT *
FROM #FATCAPivotedData; -- 1020 Rows



--Select * from
--#FATCAPivotedData
--where regime = 'FATCA_CRS'

