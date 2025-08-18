-- Step 1: Create a Tax Regime Mapping Table
-- This mapping is used to determine the applicable tax regimes based on specific flags in the CRM data.
--Purpose:

--The goal of this step is to create a temporary mapping table (#TaxRegimeMapping) that links ReportCode values from the CRM system to their corresponding TaxRegime descriptions and simplified Regime classifications. 
--This mapping is crucial for determining the applicable tax regimes (FATCA, CRS, or both) for reporting purposes under the FATCA and CRS regulations.

IF OBJECT_ID('tempdb..#TaxRegimeMapping') IS NOT NULL DROP TABLE #TaxRegimeMapping;
WITH TaxRegimeMapping AS (
    SELECT 15 AS ReportCode, 'CRS & FATCA (Entity & Individual)' AS TaxRegime,'FATCA_CRS' AS Regime UNION ALL --Definetely FATCA_CRS
    SELECT 14, 'CRS (Entity & Individual) & FATCA (Entity)','FATCA_CRS' UNION ALL ----Definetely FATCA_CRS
    SELECT 13, 'CRS (Entity) & FATCA (Entity & Individual)','FATCA_CRS' UNION ALL --Definetely FATCA_CRS
    SELECT 12, 'CRS & FATCA (Entity)','FATCA_CRS'UNION ALL --Definetely FATCA_CRS
    SELECT 11, 'CRS (Entity) & FATCA (Individual)','FATCA_CRS' UNION ALL --CRM Data Error, should still report in 'FATCA_CRS'
    SELECT 10, 'CRS (Entity & Individual)','CRS' UNION ALL -- Definetely CRS
    SELECT 9,  'CRS (Entity) & FATCA (Individual)','FATCA_CRS' UNION ALL --CRM Data Error, should still report in 'FATCA_CRS'
    SELECT 8,  'CRS (Entity)', 'CRS' UNION ALL --CRM Data Error, should still report in CRS
    SELECT 7,  'CRS (Individual) & FATCA (Entity & Individual)' ,'FATCA_CRS'UNION ALL --CRM Data Error, PWAS might put the flagg incoreclly,should still report in 'FATCA_CRS'
    SELECT 6,  'CRS (Individual) & FATCA (Entity)','FATCA_CRS' UNION ALL  --CRM Data Error, 'FATCA_CRS'
    SELECT 5,  'FATCA (Entity & Individual)' , 'FATCA' UNION ALL --FATCA
    SELECT 4,  'FATCA (Entity)','FATCA' UNION ALL --FATCA
    SELECT 3,  'CRS & FATCA (Individual)','FATCA_CRS' UNION ALL ----Definetely FATCA_CRS , PWAS might forget to flag at the entity Level, still need to report FATCA_CRS
    SELECT 2,  'CRS (Individual)', 'CRS' UNION ALL -- Definely CRS
    SELECT 1,  'FATCA (Individual)','FATCA' UNION ALL -- Definely FATCA
    SELECT 0,  'Other', 'Other'
)SELECT * INTO #TaxRegimeMapping FROM TaxRegimeMapping;


----------------------------
-- Step 2-- Build a recursive hierarchy of entities starting from entities that meet the FATCA/CRS criteria

-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#RecursiveHierarchy') IS NOT NULL DROP TABLE #RecursiveHierarchy;

;WITH RecursiveHierarchy AS (

    -- Anchor Member: Start with entities that meet the FATCA/CRS criteria
    SELECT
        a.AccountId AS EntityId,
        a.Name AS EntityName,
        0 AS Level,
        CAST(a.Name AS NVARCHAR(MAX)) AS Path,
        a.AccountId AS RootEntityId,
        -- FATCA and CRS flags at the entity level
        CASE WHEN a.dsl_USCitizensforTaxPurposes = 1 THEN 1 ELSE 0 END AS Entity_FATCA_Flag,
        CASE WHEN a.ots_foreigntaxresident = 1 THEN 1 ELSE 0 END AS Entity_CRS_Flag,

        -- Determine if the entity is a Layered Entity or Normal Entity
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r_inner
                WHERE r_inner.dsl_TradingEntityID = a.AccountId
                    AND r_inner.statuscode = 1
                    AND r_inner.dsl_OrganisationName IS NOT NULL
            ) THEN 'Layered Entity'
            ELSE 'Normal Entity'
        END AS EntityFlag

    FROM [Dynamics].[CRM_MSCRM].dbo.Account AS a
    -- Join to get the Trading Entity Type
    LEFT JOIN [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm
        ON sm.AttributeValue = a.dsl_TradingEntityType
        AND sm.AttributeName = 'dsl_tradingentitytype'
    WHERE
        -- Include entities of specified types
        sm.Value IN ('Trust', 'Company', 'Incorporated Entity', 'Partnership')
        -- Entity must have FATCA or CRS flag set
        AND (
            a.dsl_USCitizensforTaxPurposes = 1
            OR a.ots_foreigntaxresident = 1
        )
        -- Exclude certain Trusts (e.g., charities)
        AND NOT (
            sm.Value = 'Trust'
            AND a.cip_CharityNumber IS NOT NULL
        )

    UNION ALL

    -- Recursive Member: Traverse to child entities (layered entities)
    SELECT
        c.AccountId AS EntityId,
        c.Name AS EntityName,
        rh.Level + 1 AS Level,
        CAST(rh.Path + N' -> ' + c.Name AS NVARCHAR(MAX)) AS Path,
        rh.RootEntityId,
        -- Inherit FATCA and CRS flags from the root entity
        rh.Entity_FATCA_Flag,
        rh.Entity_CRS_Flag,
        -- Determine if the entity is a Layered Entity or Normal Entity
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r_inner
                WHERE r_inner.dsl_TradingEntityID = c.AccountId
                    AND r_inner.statuscode = 1
                    AND r_inner.dsl_OrganisationName IS NOT NULL
            ) THEN 'Layered Entity'
            ELSE 'Normal Entity'
        END AS EntityFlag
        
    FROM
        RecursiveHierarchy rh
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r
        ON rh.EntityId = r.dsl_TradingEntityID
        AND r.statuscode = 1
        AND r.dsl_OrganisationName IS NOT NULL -- Indicates a link to another organization
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.Account AS c
        ON r.dsl_Organisation = c.AccountId
    WHERE
        rh.Level < 3 -- Limit recursion depth to prevent infinite loops
)

-- Select the results into a temporary table
SELECT * INTO #RecursiveHierarchy FROM RecursiveHierarchy;



----- test the flags is correct, CRS reprotin gLayereds Eneities
--SELECT * FROM #RecursiveHierarchy
--where
--EntityName IN(
--'Waterview Superannuation Fund',
--'The Von Oertzen Family Trust',
--'Sylvan Trust - Australia',
--'Spandou Trust',
--'Barraclough Enterprises Limited',
--'Seidenstücker Family Trust',
--'Marion Williams Superannuation Fund',
--'Johnstone Hurst Superannuation Fund',
--'L W Haddrell Family Trust',
--'Hot Chilliz Superannuation Fund',
--'John Hepworth Superannuation Fund'
--)











---------------------------------------------------

----Step 3 Collect individuals associated with the entities in the hierarchy

-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#HierarchyIndividuals') IS NOT NULL DROP TABLE #HierarchyIndividuals;

;WITH HierarchyIndividuals AS (
    SELECT DISTINCT
        rh.RootEntityId,
        rh.EntityId,
        rh.Level,
        i.ContactId AS IndividualId,
        i.FullName AS IndividualName,
        rh.Path,
        rh.Entity_FATCA_Flag,
        rh.Entity_CRS_Flag,
        rh.EntityFlag
    FROM
        #RecursiveHierarchy rh
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r
        ON rh.EntityId = r.dsl_TradingEntityID
        AND r.statuscode = 1
        AND r.dsl_IndividualId IS NOT NULL
        AND r.dsl_RoleTypeIdName IN (
            'Director',
            'Trustee',
            'Authorised Person',
            'Corporate Trustee Agent',
            'Shareholder',
            'Settlor (Trust)',
            'Officer',
            'Other',
            'Beneficiary'
        )
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.Contact AS i
        ON r.dsl_IndividualId = i.ContactId
)

-- Select the results into a temporary table
SELECT * INTO #HierarchyIndividuals FROM HierarchyIndividuals; --1127 rows

---------------------------------------------------


-- Step 4 Extract Entity Data with Controlling Individuals, i have to conformed the Columsn struture to make sure it run on the later steps, if you are devleoeprs you might want tosee previouys step for hpw i dfdeined the Level
-- level 0 is parents >> Level 3 is the lowest, checkeed all the level, lvele 3 is the desspest level

-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#EntityData') IS NOT NULL DROP TABLE #EntityData;

;WITH EntityData AS (
    SELECT DISTINCT
        -- Account Type: 'Layered Entity' or 'Normal Entity'
        hi.EntityFlag AS AccountType,
        -- Account ID
        rh.EntityId AS AccountID,
        -- Individual Details
        hi.IndividualId,
        hi.IndividualName,
        i.FirstName,
        i.MiddleName,
        i.LastName,
        i.Telephone1 AS Tel1,
        i.Telephone2 AS Tel2,
        i.Telephone3 AS Tel3,
        ISNULL(i.Address1_Line1, '') AS ResidentialAddressLine1,
        ISNULL(i.Address1_Line2, '') AS ResidentialAddressLine2,
        ISNULL(i.Address1_Line3, '') AS ResidentialAddressLine3,
        ISNULL(i.Address1_City, '') AS ResidentialCity,
        ISNULL(i.Address1_PostalCode, '') AS ResidentialPostalCode,
        ISNULL(i.Address2_Line1, '') AS PostalAddressLine1,
        ISNULL(i.Address2_Line2, '') AS PostalAddressLine2,
        ISNULL(i.Address2_Line3, '') AS PostalAddressLine3,
        ISNULL(i.Address2_City, '') AS PostalCity,
        ISNULL(i.Address2_PostalCode, '') AS PostalPostCode,
        -- Country Information
        a.dsl_CountryTrustEstablishedIdName AS TrustCountry,
        a.dsl_PrimaryTaxDomicileName AS OrgPrimaryTaxDomicile,
        i.dsl_Address1CountryLookupIdName AS ResidentialCountry1,
        i.dsl_Address2CountryLookupIdName AS PostalCountry2,
        i.dsl_Address3CountryLookupIdName AS RegisteredOfficeCountry3,
        i.dsl_countryofresidenceidname AS ResidentialCountry2,
        a.dsl_Address1CountryLookupIdName AS CountryofResidence,
        a.dsl_Address2CountryLookupIdName AS Country2ofResidence,
        a.dsl_Address3CountryLookupIdName AS Country3ofResidence,
        i.dsl_CountryofCitizenshipIdName AS CountryofCitizenship,
        i.dsl_CountryofTaxResidencyName AS CountryofTaxResidency,
        -- Entity Information
        a.Name AS EntityName,
        a.AccountId AS EntityID,
        trm.TaxRegime,
        -- Entity Tax Identification Number (TIN)
        ft1.cip_identification AS EntityTIN,
        ft1.cip_IDTypeName AS EntityIDTypeName,
        ft1.cip_CountryJurisdictionName AS EntityCountryJurisdictionName,
        cc1.cip_ISOcode COLLATE DATABASE_DEFAULT AS EntityTaxCodeCountryISO,
        cc1.dsl_countryname COLLATE DATABASE_DEFAULT AS EntityTaxCodeCountryName,
        -- Individual Tax Identification Number (TIN)
        ft2.cip_identification AS cip_Identification,
        ft2.cip_IDTypeName AS IndividualIDTypeName,
        ft2.cip_CountryJurisdictionName AS IndividualCountryJurisdictionName,
        cc2.cip_ISOcode COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryISO,
        cc2.dsl_countryname COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryName,
        -- Portfolio Information
        ps.dsl_portfolioid,
        ps.dsl_PortfolioIdName AS PortfolioNo,
        ps.dsl_PortfolioServiceLevelName,
        -- Role Information
        r.dsl_RoleTypeIdName,
        r.dsl_BeneficialOwner,
        r.dsl_BeneficiaryOwnership,
        -- Determine Substantial Controlling Interest
        CASE
            WHEN
                rh.Entity_FATCA_Flag = 1 AND
                (
                    (r.dsl_BeneficiaryOwnership > 25 AND sm.Value = 'Company')
                    OR
                    (sm.Value NOT IN ('Individual', 'Joint', 'Minor Under 18 yrs', 'Company'))
                )
            THEN 1
            WHEN
                rh.Entity_CRS_Flag = 1 AND
                (
                    (r.dsl_BeneficiaryOwnership > 10 AND sm.Value = 'Company')
                    OR
                    (sm.Value NOT IN ('Individual', 'Joint', 'Minor Under 18 yrs', 'Company'))
                )
            THEN 1
            ELSE 0
        END AS SubstantialControllingInterest,
        r.dsl_applicant,
        r.dsl_Authorised,
        -- Trading Entity Type
        sm.Value AS TradingEntityType,
        smPS.Value AS PortfolioServiceStatus,
        -- Self-Certification and Passive/Active Status
        sm1.Value AS CRSCert,
        sm2.Value AS PassiveActive,
        -- Portfolio Dates
        ps.dsl_inceptiondate,
        ps.dsl_CloseDate,
        -- Additional Individual Information
        i.dsl_CountryOfBirthIdName COLLATE DATABASE_DEFAULT AS CountryofBirthIdName,
        rh.Entity_FATCA_Flag AS USCitizensforTaxPurposes_acc,
        i.dsl_USCitizensforTaxPurposes AS USCitizensforTaxPurposes_ind,
        CONVERT(VARCHAR(19), DATEADD(HOUR, 13, i.BirthDate), 101) COLLATE DATABASE_DEFAULT AS DOB,
        ps.dsl_CloseDate AS ClosureDate,
        i.cip_TownCityofBirth COLLATE DATABASE_DEFAULT AS TownCityofBirth,
        -- Determine Reporting Regime
        trm.Regime
    FROM
        #HierarchyIndividuals hi
    INNER JOIN #RecursiveHierarchy rh
        ON hi.RootEntityId = rh.RootEntityId
        AND hi.EntityId = rh.EntityId
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.Contact AS i
        ON hi.IndividualId = i.ContactId
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.Account AS a
        ON rh.EntityId = a.AccountId
    INNER JOIN [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r
        ON rh.EntityId = r.dsl_TradingEntityID
        AND r.dsl_IndividualId = hi.IndividualId
        AND r.statuscode = 1
    LEFT JOIN [Dynamics].[CRM_MSCRM].dbo.dsl_portfolioservice AS ps
        ON ps.dsl_TradingEntityId = a.AccountId
    LEFT JOIN [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm
        ON sm.AttributeValue = a.dsl_TradingEntityType
        AND sm.AttributeName = 'dsl_tradingentitytype'
    LEFT JOIN [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm1
        ON sm1.objecttypecode = 2
        AND sm1.AttributeName = 'cip_SelfCertification'
        AND sm1.AttributeValue = i.cip_SelfCertification
    LEFT JOIN [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm2
        ON sm2.AttributeName = 'dsl_passiveoractive'
        AND sm2.AttributeValue = a.dsl_PassiveorActive
    LEFT JOIN [Dynamics].[CRM_MSCRM].dbo.StringMap AS smPS
        ON smPS.AttributeName = 'dsl_PortfolioServiceStatus'
        AND smPS.AttributeValue = ps.dsl_PortfolioServiceStatus
    LEFT JOIN [Dynamics].[CRM_MSCRM].[dbo].[cip_foreigntaxrecord] AS ft1
        ON a.AccountId = ft1.cip_Entity
    LEFT JOIN [Dynamics].[CRM_MSCRM].[dbo].[cip_foreigntaxrecord] AS ft2
        ON ft2.cip_Individual = i.ContactId
    LEFT JOIN [Dynamics].[CRM_MSCRM].[dbo].[dsl_countryBase] AS cc1
        ON cc1.dsl_countryid = ft1.cip_CountryJurisdiction
        AND cc1.statuscode = 1
    LEFT JOIN [Dynamics].[CRM_MSCRM].[dbo].[dsl_countryBase] AS cc2
        ON cc2.dsl_countryid = ft2.cip_CountryJurisdiction
        AND cc2.statuscode = 1
    LEFT JOIN #TaxRegimeMapping AS trm
        ON trm.ReportCode = (
            (rh.Entity_CRS_Flag * 8) +
            (rh.Entity_FATCA_Flag * 4) +
            (CASE WHEN i.ots_foreigntaxresident = 1 THEN 1 ELSE 0 END * 2) +
            (CASE WHEN i.dsl_USCitizensforTaxPurposes = 1 THEN 1 ELSE 0 END)
        )
    WHERE
        sm.Value IN ('Trust', 'Company', 'Incorporated Entity', 'Partnership')
        AND (
            rh.Entity_FATCA_Flag = 1
            OR rh.Entity_CRS_Flag = 1
        )
        AND ft1.cip_CountryJurisdiction IS NOT NULL
        AND ft1.cip_Identification IS NOT NULL
        AND ISNULL(cc1.cip_ISOCode, '') <> 'NZL'
        AND NOT (
            sm.Value = 'Trust'
            AND ISNULL(sm2.Value, '') = 'Passive'
            AND a.cip_CharityNumber IS NOT NULL
        )
        -- Exclude New Zealand TINs for individuals
        AND ISNULL(cc2.cip_ISOCode, '') <> 'NZL'
        -- Exclude data errors
        AND trm.TaxRegime NOT IN ('CRS (Individual) & FATCA (Entity)', 'CRS (Entity) & FATCA (Individual)')
)

-- Select the results into a temporary table
SELECT * INTO #EntityData FROM EntityData;


---- Check Distribution
--SELECT 
--    ed.TaxRegime,
--    ed.Regime,
--    COUNT(*) AS RecordCount
--FROM #EntityData AS ed
--GROUP BY ed.TaxRegime, ed.Regime;




------------------------------------------


-- Step 5: Extract Individual Data that related to FATCA adn CRS
-- Purpose: Retrieve data for individual account holders, including their tax identification numbers (TINs) and other relevant information for FATCA and CRS reporting.
-- Use a CTE to calculate TIN counts per partition by (a.AccountId, ps.dsl_PortfolioIdName AS PortfolioNo,ps.dsl_PortfolioServiceLevelName,i.ContactId AS IndividualId,)
--eg. using Sarah as examples 

-- Step 5.1: Calculate TIN counts per partition and store in a temporary table

-- Drop the temporary table if it already exists
IF OBJECT_ID('tempdb..#TIN_Counts') IS NOT NULL DROP TABLE #TIN_Counts;

-- Create temporary table #TIN_Counts
SELECT
    a.AccountId,
    ps.dsl_PortfolioIdName AS PortfolioNo,
    ps.dsl_PortfolioServiceLevelName,
    i.ContactId AS IndividualId,
    COUNT(DISTINCT ft2.cip_identification) AS TIN_Count
INTO #TIN_Counts
FROM 
    [Dynamics].[CRM_MSCRM].dbo.Account AS a
INNER JOIN 
    [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r
        ON a.AccountId = r.dsl_TradingEntityID
        AND r.statuscode = 1
        AND r.dsl_BeneficialOwner = 1
INNER JOIN 
    [Dynamics].[CRM_MSCRM].dbo.Contact AS i
        ON i.ContactId = r.dsl_IndividualId
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].dbo.dsl_portfolioservice AS ps
        ON ps.dsl_TradingEntityId = a.AccountId
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].[dbo].[cip_foreigntaxrecord] AS ft2
        ON ft2.cip_Individual = i.ContactId
WHERE
    -- Ensure the individual's TIN and country jurisdiction are not null
    ft2.cip_CountryJurisdiction IS NOT NULL
    AND ft2.cip_Identification IS NOT NULL
    AND (
        -- FATCA Individuals may have multiple citizenships, which means multiple TINs
        i.dsl_USCitizensforTaxPurposes = 1
        OR
        -- CRS Individuals may also have multiple citizenships
        i.ots_foreigntaxresident = 1
    )
GROUP BY
    a.AccountId,
    ps.dsl_PortfolioIdName,
    ps.dsl_PortfolioServiceLevelName,
    i.ContactId;

-- Step 5.2: Extract Individual Data related to FATCA and CRS

-- Drop the temporary table if it already exists
IF OBJECT_ID('tempdb..#IndividualData') IS NOT NULL DROP TABLE #IndividualData;

-- Create temporary table #IndividualData
SELECT DISTINCT
    -- Determine AccountType based on the number of TINs an individual has within the correct partitions.
    CASE 
        WHEN tc.TIN_Count > 1 THEN 'Multiple TINs Individual' 
        ELSE 'Single TIN Individual' 
    END AS AccountType,

    -- The individual's ContactId serves as the AccountID in this context.
    i.ContactId AS AccountID,
	 
    -- Individual Details
    i.ContactId AS IndividualId,
    i.FullName AS IndividualName,
    i.FirstName,
    i.MiddleName,
    i.LastName,
    i.Telephone1 AS Tel1,
    i.Telephone2 AS Tel2,
    i.Telephone3 AS Tel3,
    -- Residential Address Information
    ISNULL(i.Address1_Line1, '') AS ResidentialAddressLine1,
    ISNULL(i.Address1_Line2, '') AS ResidentialAddressLine2,
    ISNULL(i.Address1_Line3, '') AS ResidentialAddressLine3,
    ISNULL(i.Address1_City, '') AS ResidentialCity,
    ISNULL(i.Address1_PostalCode, '') AS ResidentialPostalCode,
    -- Postal Address Information
    ISNULL(i.Address2_Line1, '') AS PostalAddressLine1,
    ISNULL(i.Address2_Line2, '') AS PostalAddressLine2,
    ISNULL(i.Address2_Line3, '') AS PostalAddressLine3,
    ISNULL(i.Address2_City, '') AS PostalCity,
    ISNULL(i.Address2_PostalCode, '') AS PostalPostCode,
    -- Country Information
        a.dsl_CountryTrustEstablishedIdName AS TrustCountry,
        a.dsl_PrimaryTaxDomicileName AS OrgPrimaryTaxDomicile,
        i.dsl_Address1CountryLookupIdName AS ResidentialCountry1,
        i.dsl_Address2CountryLookupIdName AS PostalCountry2,
        i.dsl_Address3CountryLookupIdName AS RegisteredOfficeCountry3,
        i.dsl_countryofresidenceidname AS ResidentialCountry2,
        a.dsl_Address1CountryLookupIdName AS CountryofResidence,
        a.dsl_Address2CountryLookupIdName AS Country2ofResidence,
        a.dsl_Address3CountryLookupIdName AS Country3ofResidence,
        i.dsl_CountryofCitizenshipIdName AS CountryofCitizenship,
        i.dsl_CountryofTaxResidencyName AS CountryofTaxResidency,
    -- Entity Information (for individuals, EntityName may be their own name or account name)
    a.Name AS EntityName,
    a.AccountId AS EntityID,
    -- Determine the Reporting Regime based on individual flags
    trm.TaxRegime,
    -- Entity Tax Identification Number (TIN) - Deliberately left empty for individuals
    '' AS EntityTIN,
    '' AS EntityIDTypeName,
    '' AS EntityCountryJurisdictionName,
    '' AS EntityTaxCodeCountryISO,
    '' AS EntityTaxCodeCountryName,
    -- Individual Tax Identification Number (TIN)
    ft2.cip_identification AS cip_Identification,
    ft2.cip_IDTypeName AS IndividualIDTypeName,
    ft2.cip_CountryJurisdictionName AS IndividualCountryJurisdictionName,
    cc2.cip_ISOcode COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryISO,
    cc2.dsl_countryname COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryName,
    -- Portfolio Information
    ps.dsl_portfolioid,
    ps.dsl_PortfolioIdName AS PortfolioNo,
    ps.dsl_PortfolioServiceLevelName,
    -- Role Information
    r.dsl_RoleTypeIdName,
    r.dsl_BeneficialOwner,
    r.dsl_BeneficiaryOwnership,
    -- Determine Substantial Controlling Interest
    CASE
        WHEN r.dsl_BeneficialOwner = 1 AND r.dsl_BeneficiaryOwnership > 25 AND sm.Value = 'Company' THEN 1
        WHEN sm.Value NOT IN ('Individual', 'Joint', 'Minor Under 18 yrs', 'Company') AND r.dsl_BeneficialOwner = 1 THEN 1
        ELSE 0
    END AS SubstantialControllingInterest,
    r.dsl_applicant,
    r.dsl_Authorised,
    -- Trading Entity Type and Portfolio Service Status
    sm.Value AS TradingEntityType,
    smPS.Value AS PortfolioServiceStatus,
    -- Self-Certification and Passive/Active Status
    sm1.Value AS CRSCert,
    sm2.Value AS PassiveActive,
    -- Portfolio Dates
    ps.dsl_inceptiondate,
    ps.dsl_CloseDate,
    -- Additional Individual Information like birth place and closure date
    i.dsl_CountryOfBirthIdName COLLATE DATABASE_DEFAULT AS CountryofBirthIdName,
    a.dsl_USCitizensforTaxPurposes AS USCitizensforTaxPurposes_acc,
    i.dsl_USCitizensforTaxPurposes AS USCitizensforTaxPurposes_ind,
    CONVERT(VARCHAR(19), DATEADD(HOUR, 13, i.BirthDate), 101) COLLATE DATABASE_DEFAULT AS DOB,
    ps.dsl_CloseDate AS ClosureDate,
    i.cip_TownCityofBirth COLLATE DATABASE_DEFAULT AS TownCityofBirth,

	-- addded the Regime flags
	trm.Regime

INTO #IndividualData
FROM 
    [Dynamics].[CRM_MSCRM].dbo.Account AS a
INNER JOIN 
    [Dynamics].[CRM_MSCRM].dbo.dsl_roles AS r
        ON a.AccountId = r.dsl_TradingEntityID
        AND r.statuscode = 1
        AND r.dsl_BeneficialOwner = 1
INNER JOIN 
    [Dynamics].[CRM_MSCRM].dbo.Contact AS i
        ON i.ContactId = r.dsl_IndividualId
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].dbo.dsl_portfolioservice AS ps
        ON ps.dsl_TradingEntityId = a.AccountId
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm
        ON sm.AttributeValue = a.dsl_TradingEntityType
        AND sm.AttributeName = 'dsl_tradingentitytype'
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm1
        ON sm1.objecttypecode = 2
        AND sm1.AttributeName = 'cip_SelfCertification'
        AND sm1.AttributeValue = i.cip_SelfCertification
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].dbo.StringMap AS sm2
        ON sm2.AttributeName = 'dsl_passiveoractive'
        AND sm2.AttributeValue = a.dsl_PassiveorActive
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].dbo.StringMap AS smPS
        ON smPS.AttributeName = 'dsl_PortfolioServiceStatus'
        AND smPS.AttributeValue = ps.dsl_PortfolioServiceStatus
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].[dbo].[cip_foreigntaxrecord] AS ft2
        ON ft2.cip_Individual = i.ContactId
LEFT JOIN 
    [Dynamics].[CRM_MSCRM].[dbo].[dsl_countryBase] AS cc2
        ON cc2.dsl_countryid = ft2.cip_CountryJurisdiction
        AND cc2.statuscode = 1
LEFT JOIN 
    #TaxRegimeMapping AS trm
        ON trm.ReportCode = (
            (CASE WHEN a.ots_foreigntaxresident = 1 THEN 1 ELSE 0 END * 8) +
            (CASE WHEN a.dsl_USCitizensforTaxPurposes = 1 THEN 1 ELSE 0 END * 4) +
            (CASE WHEN i.ots_foreigntaxresident = 1 THEN 1 ELSE 0 END * 2) +
            (CASE WHEN i.dsl_USCitizensforTaxPurposes = 1 THEN 1 ELSE 0 END)
        )
LEFT JOIN -- Use TIN_Counts to get the correct partitions for Individuals' TINs
    #TIN_Counts AS tc
        ON tc.AccountId = a.AccountId
        AND tc.PortfolioNo = ps.dsl_PortfolioIdName
        AND tc.dsl_PortfolioServiceLevelName = ps.dsl_PortfolioServiceLevelName
        AND tc.IndividualId = i.ContactId
WHERE
    -- Exclude New Zealand TINs for individuals
    ISNULL(cc2.cip_ISOCode, '') <> 'NZL'
    -- Exclude certain trusts (e.g., charities)
    AND NOT (
        sm.Value = 'Trust'
        AND ISNULL(sm2.Value, '') = 'Passive'
        AND a.cip_CharityNumber IS NOT NULL
    )
    -- Exclude 'Estate Winding-Up' entity types
    AND sm.Value <> 'Estate Winding-Up'
    -- Ensure the individual's TIN and country jurisdiction are not null
    AND ft2.cip_CountryJurisdiction IS NOT NULL
    AND ft2.cip_Identification IS NOT NULL
    -- Include only specified trading entity types
    AND sm.Value IN ('Individual', 'Joint', 'Minor Under 18 yrs')
    -- Exclude tax regimes that are logically inconsistent
    AND trm.TaxRegime NOT IN ('CRS (Individual) & FATCA (Entity)', 'CRS (Entity) & FATCA (Individual)')
    AND (
        -- FATCA Individuals may have multiple citizenships, which means multiple TINs
        i.dsl_USCitizensforTaxPurposes = 1
        OR
        -- CRS Individuals may also have multiple citizenships
        i.ots_foreigntaxresident = 1
    );


-- -- Validation Script # 1 to Check AccountType Assignment

--SELECT
--    tc.AccountId,
--    tc.PortfolioNo,
--    tc.dsl_PortfolioServiceLevelName,
--    tc.IndividualId,
--    tc.TIN_Count,
--    CASE 
--        WHEN tc.TIN_Count > 1 THEN 'Multiple TINs Individual' 
--        ELSE 'Single TIN Individual' 
--    END AS CalculatedAccountType,
--    id.AccountType AS OriginalAccountType
--FROM
--    #TIN_Counts AS tc
--INNER JOIN
--    #IndividualData AS id
--        ON id.AccountID = tc.IndividualId
--        AND id.EntityID = tc.AccountId
--        AND id.PortfolioNo = tc.PortfolioNo
--        AND id.dsl_PortfolioServiceLevelName = tc.dsl_PortfolioServiceLevelName
--		--wher calsie os to comapre if any mistach
----WHERE
----    id.AccountType <> (CASE WHEN tc.TIN_Count > 1 THEN 'Multiple TINs Individual' ELSE 'Single TIN Individual' END)
----ORDER BY
----    tc.TIN_Count DESC, id.IndividualName;


-- Validation Script #2: Check Tax Regime and Regime Assignment

---- Select data from #IndividualData along with flags and calculated Tax Regime

--Select * FROM #IndividualData id
--WHERE
--id.TaxRegime = 'CRS (Entity & Individual) & FATCA (Entity)'
--AND id.Regime= 'FATCA_CRS'


----SELECT 
----    id.TaxRegime,
----    id.Regime,
----    COUNT(*) AS RecordCount
----FROM #IndividualData AS id
----GROUP BY id.TaxRegime, id.Regime;




----------------------------------

-- Step 6 : Combine Entity and Individual Data with Complex Filtering to get rid of some  data as per the Original scritps 
-- Comprehensive Filtering Logic
--Entities:
--Must be either 'Layered Entity' or 'Normal Entity'.
--Must fall under 'FATCA', 'CRS', or 'FATCA_CRS'.
--Must have a TIN or be Passive.
--Must meet Role and Ownership conditions.
--If TIN is Provided, ensure US Citizenship is not 'No'.

--Individuals:
--Must be 'Multple TINS Individual' or 'Single TIN Indiviudal'
--Must have a TIN or be Passive.
--Must fall under 'FATCA', 'CRS', or 'FATCA_CRS'.
--For 'FATCA' and 'FATCA_CRS' regimes:
--If TIN is Provided, ensure US Citizenship is not 'No'.

--PortfolioServiceLevelName Exclusions
--Purpose: Excludes specific portfolios that are not reportable under FATCA or CRS.
--Conditions:
--FATCA: Excludes ('', 'QuayStreet KiwiSaver Scheme', 'Craigs KiwiSaver', 'superSTART', 'Craigs Super').
--CRS & FATCA_CRS: Excludes ('', 'QuayStreet KiwiSaver Scheme', 'Craigs KiwiSaver').

--Exclusion of 'Estate Winding-Up' Entities
--Purpose: Ensures that entities involved in winding up estates are excluded from reporting.

--Role and Ownership Conditions
--Entities:
--Identifies beneficial owners, applicants, and authorized persons.
--Ensures that entities with key controlling individuals are reportable.

--US Citizenship and TIN Conditions
--Entities:
--Ensures that entities with a provided TIN are not explicitly marked as 'No' for US citizenship.
--Individuals:
--Ensures that individuals with a provided TIN are not explicitly marked as 'No' for US citizenship.



-- Drop the final filtered temporary table if it exists to avoid duplication errors
IF OBJECT_ID('tempdb..##crmdatafatcacrs') IS NOT NULL 
    DROP TABLE ##crmdatafatcacrs;

-- Create ##crmdatafatcacrs by combining #EntityData and #IndividualData, applying collation, and filtering in one singel steps
SELECT *
INTO ##crmdatafatcacrs -- Final Filtered Data for Reporting
FROM (
    -- Combine Entity Data
    SELECT
        -- Apply COLLATE DATABASE_DEFAULT to all string columns
        AccountType COLLATE DATABASE_DEFAULT AS AccountType,
        AccountID,
        IndividualId,
        IndividualName COLLATE DATABASE_DEFAULT AS IndividualName,
        FirstName COLLATE DATABASE_DEFAULT AS FirstName,
        MiddleName COLLATE DATABASE_DEFAULT AS MiddleName,
        LastName COLLATE DATABASE_DEFAULT AS LastName,
        Tel1 COLLATE DATABASE_DEFAULT AS Tel1,
        Tel2 COLLATE DATABASE_DEFAULT AS Tel2,
        Tel3 COLLATE DATABASE_DEFAULT AS Tel3,
        ResidentialAddressLine1 COLLATE DATABASE_DEFAULT AS ResidentialAddressLine1,
        ResidentialAddressLine2 COLLATE DATABASE_DEFAULT AS ResidentialAddressLine2,
        ResidentialAddressLine3 COLLATE DATABASE_DEFAULT AS ResidentialAddressLine3,
        ResidentialCity COLLATE DATABASE_DEFAULT AS ResidentialCity,
        ResidentialPostalCode COLLATE DATABASE_DEFAULT AS ResidentialPostalCode,
        PostalAddressLine1 COLLATE DATABASE_DEFAULT AS PostalAddressLine1,
        PostalAddressLine2 COLLATE DATABASE_DEFAULT AS PostalAddressLine2,
        PostalAddressLine3 COLLATE DATABASE_DEFAULT AS PostalAddressLine3,
        PostalCity COLLATE DATABASE_DEFAULT AS PostalCity,
        PostalPostCode COLLATE DATABASE_DEFAULT AS PostalPostCode,
        TrustCountry COLLATE DATABASE_DEFAULT AS TrustCountry,
        OrgPrimaryTaxDomicile COLLATE DATABASE_DEFAULT AS OrgPrimaryTaxDomicile,
        ResidentialCountry1 COLLATE DATABASE_DEFAULT AS ResidentialCountry1,
        PostalCountry2 COLLATE DATABASE_DEFAULT AS PostalCountry2,
        RegisteredOfficeCountry3 COLLATE DATABASE_DEFAULT AS RegisteredOfficeCountry3,
        ResidentialCountry2 COLLATE DATABASE_DEFAULT AS ResidentialCountry2,
        CountryofResidence COLLATE DATABASE_DEFAULT AS CountryofResidence,
        Country2ofResidence COLLATE DATABASE_DEFAULT AS Country2ofResidence,
        Country3ofResidence COLLATE DATABASE_DEFAULT AS Country3ofResidence,
        CountryofCitizenship COLLATE DATABASE_DEFAULT AS CountryofCitizenship,
        CountryofTaxResidency COLLATE DATABASE_DEFAULT AS CountryofTaxResidency,
        EntityName COLLATE DATABASE_DEFAULT AS EntityName,
        EntityID,
        TaxRegime COLLATE DATABASE_DEFAULT AS TaxRegime,
        EntityTIN COLLATE DATABASE_DEFAULT AS EntityTIN,
        EntityIDTypeName COLLATE DATABASE_DEFAULT AS EntityIDTypeName,
        EntityCountryJurisdictionName COLLATE DATABASE_DEFAULT AS EntityCountryJurisdictionName,
        EntityTaxCodeCountryISO COLLATE DATABASE_DEFAULT AS EntityTaxCodeCountryISO,
        EntityTaxCodeCountryName COLLATE DATABASE_DEFAULT AS EntityTaxCodeCountryName,
        cip_Identification COLLATE DATABASE_DEFAULT AS cip_Identification,
        IndividualIDTypeName COLLATE DATABASE_DEFAULT AS IndividualIDTypeName,
        IndividualCountryJurisdictionName COLLATE DATABASE_DEFAULT AS IndividualCountryJurisdictionName,
        Ind_TaxCodeCountryISO COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryISO,
        Ind_TaxCodeCountryName COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryName,
        dsl_portfolioid,
        PortfolioNo COLLATE DATABASE_DEFAULT AS PortfolioNo,
        dsl_PortfolioServiceLevelName COLLATE DATABASE_DEFAULT AS PortfolioServiceLevelName,
        dsl_RoleTypeIdName COLLATE DATABASE_DEFAULT AS dsl_RoleTypeIdName,
        dsl_BeneficialOwner,
        dsl_BeneficiaryOwnership,
        SubstantialControllingInterest,
        dsl_applicant,
        dsl_Authorised,
        TradingEntityType COLLATE DATABASE_DEFAULT AS TradingEntityType,
        PortfolioServiceStatus COLLATE DATABASE_DEFAULT AS PortfolioServiceStatus,
        CRSCert COLLATE DATABASE_DEFAULT AS CRSCert,
        PassiveActive COLLATE DATABASE_DEFAULT AS PassiveActive,
        dsl_inceptiondate,
        dsl_CloseDate,
        CountryofBirthIdName COLLATE DATABASE_DEFAULT AS CountryofBirthIdName,
        USCitizensforTaxPurposes_acc,
        USCitizensforTaxPurposes_ind,
        DOB COLLATE DATABASE_DEFAULT AS DOB,
        ClosureDate,
        TownCityofBirth COLLATE DATABASE_DEFAULT AS TownCityofBirth,
        Regime COLLATE DATABASE_DEFAULT AS Regime
    FROM #EntityData

    UNION ALL

    -- Combine Individual Data
    SELECT
        -- Apply COLLATE DATABASE_DEFAULT to all string columns
        AccountType COLLATE DATABASE_DEFAULT AS AccountType,
        AccountID,
        IndividualId,
        IndividualName COLLATE DATABASE_DEFAULT AS IndividualName,
        FirstName COLLATE DATABASE_DEFAULT AS FirstName,
        MiddleName COLLATE DATABASE_DEFAULT AS MiddleName,
        LastName COLLATE DATABASE_DEFAULT AS LastName,
        Tel1 COLLATE DATABASE_DEFAULT AS Tel1,
        Tel2 COLLATE DATABASE_DEFAULT AS Tel2,
        Tel3 COLLATE DATABASE_DEFAULT AS Tel3,
        ResidentialAddressLine1 COLLATE DATABASE_DEFAULT AS ResidentialAddressLine1,
        ResidentialAddressLine2 COLLATE DATABASE_DEFAULT AS ResidentialAddressLine2,
        ResidentialAddressLine3 COLLATE DATABASE_DEFAULT AS ResidentialAddressLine3,
        ResidentialCity COLLATE DATABASE_DEFAULT AS ResidentialCity,
        ResidentialPostalCode COLLATE DATABASE_DEFAULT AS ResidentialPostalCode,
        PostalAddressLine1 COLLATE DATABASE_DEFAULT AS PostalAddressLine1,
        PostalAddressLine2 COLLATE DATABASE_DEFAULT AS PostalAddressLine2,
        PostalAddressLine3 COLLATE DATABASE_DEFAULT AS PostalAddressLine3,
        PostalCity COLLATE DATABASE_DEFAULT AS PostalCity,
        PostalPostCode COLLATE DATABASE_DEFAULT AS PostalPostCode,
        TrustCountry COLLATE DATABASE_DEFAULT AS TrustCountry,
        OrgPrimaryTaxDomicile COLLATE DATABASE_DEFAULT AS OrgPrimaryTaxDomicile,
        ResidentialCountry1 COLLATE DATABASE_DEFAULT AS ResidentialCountry1,
        PostalCountry2 COLLATE DATABASE_DEFAULT AS PostalCountry2,
        RegisteredOfficeCountry3 COLLATE DATABASE_DEFAULT AS RegisteredOfficeCountry3,
        ResidentialCountry2 COLLATE DATABASE_DEFAULT AS ResidentialCountry2,
        CountryofResidence COLLATE DATABASE_DEFAULT AS CountryofResidence,
        Country2ofResidence COLLATE DATABASE_DEFAULT AS Country2ofResidence,
        Country3ofResidence COLLATE DATABASE_DEFAULT AS Country3ofResidence,
        CountryofCitizenship COLLATE DATABASE_DEFAULT AS CountryofCitizenship,
        CountryofTaxResidency COLLATE DATABASE_DEFAULT AS CountryofTaxResidency,
        EntityName COLLATE DATABASE_DEFAULT AS EntityName,
        EntityID,
        TaxRegime COLLATE DATABASE_DEFAULT AS TaxRegime,
        EntityTIN COLLATE DATABASE_DEFAULT AS EntityTIN,
        EntityIDTypeName COLLATE DATABASE_DEFAULT AS EntityIDTypeName,
        EntityCountryJurisdictionName COLLATE DATABASE_DEFAULT AS EntityCountryJurisdictionName,
        EntityTaxCodeCountryISO COLLATE DATABASE_DEFAULT AS EntityTaxCodeCountryISO,
        EntityTaxCodeCountryName COLLATE DATABASE_DEFAULT AS EntityTaxCodeCountryName,
        cip_Identification COLLATE DATABASE_DEFAULT AS cip_Identification,
        IndividualIDTypeName COLLATE DATABASE_DEFAULT AS IndividualIDTypeName,
        IndividualCountryJurisdictionName COLLATE DATABASE_DEFAULT AS IndividualCountryJurisdictionName,
        Ind_TaxCodeCountryISO COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryISO,
        Ind_TaxCodeCountryName COLLATE DATABASE_DEFAULT AS Ind_TaxCodeCountryName,
        dsl_portfolioid,
        PortfolioNo COLLATE DATABASE_DEFAULT AS PortfolioNo,
        dsl_PortfolioServiceLevelName COLLATE DATABASE_DEFAULT AS PortfolioServiceLevelName,
        dsl_RoleTypeIdName COLLATE DATABASE_DEFAULT AS dsl_RoleTypeIdName,
        dsl_BeneficialOwner,
        dsl_BeneficiaryOwnership,
        SubstantialControllingInterest,
        dsl_applicant,
        dsl_Authorised,
        TradingEntityType COLLATE DATABASE_DEFAULT AS TradingEntityType,
        PortfolioServiceStatus COLLATE DATABASE_DEFAULT AS PortfolioServiceStatus,
        CRSCert COLLATE DATABASE_DEFAULT AS CRSCert,
        PassiveActive COLLATE DATABASE_DEFAULT AS PassiveActive,
        dsl_inceptiondate,
        dsl_CloseDate,
        CountryofBirthIdName COLLATE DATABASE_DEFAULT AS CountryofBirthIdName,
        USCitizensforTaxPurposes_acc,
        USCitizensforTaxPurposes_ind,
        DOB COLLATE DATABASE_DEFAULT AS DOB,
        ClosureDate,
        TownCityofBirth COLLATE DATABASE_DEFAULT AS TownCityofBirth,
        Regime COLLATE DATABASE_DEFAULT AS Regime
    FROM #IndividualData
) AS CombinedData

WHERE 1=1
    -- Date Filtering (for testing purposes, hardcoded dates)
    -- Uncomment and set variables if needed
    -- DECLARE @PeriodStartDate DATETIME = '2024-04-01';  -- Period start date
    -- DECLARE @PeriodEndDate DATETIME = '2025-03-31';    -- Period end date
    -- DECLARE @rptYear INT = YEAR(@PeriodEndDate);
    -- DECLARE @TRReportingDate DATETIME = '2025-09-29';  -- Reporting End Date

	 -- Fitlers for Portfolio Status and Date Conditions>> Why? to filter out useless outdated Portfolios services based on the reproting stanards, we only report '2024-04-01' AND '2025-03-31' each year
    AND (
        (
            PortfolioServiceStatus NOT IN ('Closed')
            OR (
                PortfolioServiceStatus = 'Closed'
                AND dsl_CloseDate BETWEEN '2024-04-01' AND '2025-03-31'
            )
        )
        AND dsl_inceptiondate <= '2025-03-31'
    )

    -- Original Sctips from Aneases Step 1 to Step 10 complex filters below >> why ? iguess it is beacuse i don't want to muck up the BA works done on this FTACA/CRS >> that's why i am using a lot original fitlers to feilter out usesless data

	--Includes only records where the Regime is specified (not NULL).
    AND Regime IS NOT NULL


    -- Exclude non-reportable portfolios, BA works doen to evalute to deceided fowlling products are not reportable, Non-Reportable Portfolios: Certain portfolios are exempt from reporting under specific regimes.
    AND (
        (
            Regime = 'FATCA'
            AND ISNULL(PortfolioServiceLevelName, '') NOT IN (
                '', 'QuayStreet KiwiSaver Scheme', 'Craigs KiwiSaver', 'superSTART', 'Craigs Super'
            )
        )
        OR (
            Regime IN ('CRS', 'FATCA_CRS') -- i added 'FATCA_CRS' in this fitler becasue JF think for acoounts that need to report udner both FATCA and CRS (2% of the Total), better put them in the bigger range of fitler
            AND ISNULL(PortfolioServiceLevelName, '') NOT IN (
                '', 'QuayStreet KiwiSaver Scheme', 'Craigs KiwiSaver'
            )
        )
    )
    -- Exclude 'Estate Winding-Up' entities, Exemption: Entities involved in estate winding-up are typically not reportable.
    AND TradingEntityType <> 'Estate Winding-Up'


    -- Apply original script's complex filtering logic

    AND (
        -- Conditions for Entities (Layered Entity or Normal Entity) -- JF added The concepts of Layered Entity whci Anease didn't cosndier
        (
            -- Include only accounts that are Entities, i have made sure the Entities (Step 2 - Step 4) are clean and made sense 
            AccountType IN ('Layered Entity', 'Normal Entity')
            AND
            -- Include entities under FATCA, CRS, or FATCA_CRS regimes
            Regime IN ('FATCA', 'CRS', 'FATCA_CRS')
            AND
            -- Include entities that either have a Tax Identification Number (TIN) or are passive entities >>
            (
                ISNULL(cip_Identification, '') <> ''  -- Entity TIN is provided
                OR (PassiveActive IS NULL OR PassiveActive != 'Active')  -- Entity is passive or PassiveActive is null
            )
            AND
            -- Role and ownership conditions to identify substantial owners or controllers
            (
                -- For entities with specific Trading Entity Types and Roles
                (
                    TradingEntityType IN ('Individual', 'Joint', 'Minor Under 18 yrs')
                    AND dsl_RoleTypeIdName IN ('Individual', '', 'Minor', 'Guardian')
                    AND (
                        dsl_BeneficialOwner = 1  -- Is a beneficial owner
                        OR dsl_applicant = 1     -- Is an applicant
                        OR dsl_Authorised = 1    -- Is authorized
                    )
                )
                OR
                -- For Companies where the individual is a beneficial owner
                (
                    TradingEntityType = 'Company'
                    AND dsl_BeneficialOwner = 1
                )
                OR
                -- For other Trading Entity Types where the individual is a beneficial owner
                (
                    TradingEntityType NOT IN ('Individual', 'Joint', 'Minor Under 18 yrs', 'Company')
                    AND dsl_BeneficialOwner = 1
                )
            )
            AND
            -- Exclude entities that have explicitly answered 'No' to US citizenship for tax purposes but have provided a TIN>> if they still have a TIn then this person is still consider US Perosn and Reportable
            (
                (
                    ISNULL(cip_Identification, '') <> ''  -- TIN is provided
                    AND ISNULL(USCitizensforTaxPurposes_acc, 1) <> 2  -- US Citizenship not explicitly 'No' (2 means 'No')
                )
                OR ISNULL(cip_Identification, '') = ''  -- TIN is not provided
            )
        )

        OR
        -- Conditions for Individuals
        (
            -- Include only accounts that are Individuals
            AccountType IN ('Multiple TINs Individual', 'Single TIN Individual')
            AND
            -- Include accounts that either have a TIN or are passive accounts
            (
                ISNULL(cip_Identification, '') <> ''  -- Individual TIN is provided
                OR (PassiveActive IS NULL OR PassiveActive != 'Active')  -- Account is passive or PassiveActive is null
            )
            AND
            -- Include accounts under FATCA, CRS, or FATCA_CRS regimes
            (
                -- For FATCA or FATCA_CRS regimes
                (
                    Regime IN ('FATCA', 'FATCA_CRS')
                    AND (
                        -- Exclude individuals who have explicitly answered 'No' to US citizenship but have provided a TIN
                        (
                            ISNULL(cip_Identification, '') <> ''  -- TIN is provided
                            AND ISNULL(USCitizensforTaxPurposes_ind, 1) <> 2  -- US Citizenship not explicitly 'No'
                        )
                        OR ISNULL(cip_Identification, '') = ''  -- TIN is not provided
                    )
                )
                OR
                -- For CRS regime
                Regime = 'CRS'
            )
        )
    )
	-- Exclude 'Standard Broking Service' Portfolios without Safe Custody Holdings and without Cash Management Account
	--Excludes 'Standard Broking Service' portfolios where the client: WHY >> Lynley said so >> JF don't really know the cotnext but she said for those people only have 'Standard Broking Service' and don' have cashman need to be excluded
 --   Does not have any safe custody holdings.
 --   Does not have a Cash Management account.
AND NOT (
    PortfolioServiceLevelName = 'Standard Broking Service' -- 
    AND NOT EXISTS (
        -- Subquery 1: Check for Safe Custody Holdings>>WHY Exclude Clients Without Holdings: Clients without safe custody holdings are not engaging in activities reportable under FATCA or CRS.
        SELECT 1
        FROM [AACARPTSRV].[fusion].[dbo].[Trn] t
        JOIN [AACARPTSRV].[fusion].[dbo].[Portfolio] p ON t.portfolioID = p.portfolioID
        JOIN [AACARPTSRV].[fusion].[dbo].[Drum] d ON p.drumID = d.drumID
        WHERE t.holdingTypeID = 3270 -- Safe Custody Nominee
            AND t.trnStatusID = 502
            AND t.settleDate <= '2025-03-31' -- Reporting period end date
            AND d.code COLLATE DATABASE_DEFAULT = CombinedData.PortfolioNo COLLATE DATABASE_DEFAULT
        GROUP BY d.code
        HAVING SUM(t.nominal) > 0
    )

    AND NOT EXISTS (
        -- Subquery 2: Check for Cash Management Account >> WHY ?Exclude Clients Without Cash Accounts: Clients without a cash management account may not be engaging in financial transactions that require reporting.
        SELECT 1
        FROM (
            SELECT AccountID, IndividualId, Regime, PortfolioServiceLevelName
            FROM #EntityData
            UNION ALL
            SELECT AccountID, IndividualId, Regime, PortfolioServiceLevelName
            FROM #IndividualData
        ) AS AllData
        WHERE AllData.AccountID = CombinedData.AccountID
            AND AllData.IndividualId = CombinedData.IndividualId
            AND AllData.Regime = CombinedData.Regime
            AND AllData.PortfolioServiceLevelName = 'Cash Management'
    )
)



--Step 6.0 -- bring in the missing country ISO code using a referecne table >> tyhis was added on Later 
-->> why? becasue i found out our CRM and Fusion some countied had the incoorect country name so i had to handle this by adding in a refrence table

	-- i forget to change the 3 letter ISO code back into the two letter ISOcode>> need to add the joins around here
	-- the data would get materialsied and then process at step 7
IF OBJECT_ID('tempdb..##crmdatafatcacrsiso') IS NOT NULL 
    DROP TABLE ##crmdatafatcacrsiso;

SELECT cr.*,
   --EntityTaxCodeCountryISO >> to 2 digit EntityTaxCodeCountryISOShort
--Ind_TaxCodeCountryISO >> to 2 digit Ind_TaxCodeCountryISOISOShort
    ISNULL(etc.ISOCode,'XX') AS EntityTaxCodeCountryISOShort,-- 'XX' indicates missing ISO code

	ISNULL(itc.ISOCode,'XX') AS Ind_TaxCodeCountryISOShort,-- 'XX' indicates missing ISO code

    ISNULL(crf.ISOCode, 'XX') AS [Res Country Code], -- 'XX' indicates missing ISO code
   
    ISNULL(pf.ISOCode, 'XX') AS [Postal Country Code], -- 'XX' indicates missing ISO code
 
    ISNULL(cb.ISOCode, 'XX') AS [Country of Birth] -- 'XX' indicates missing ISO code

INTO ##crmdatafatcacrsiso
FROM 
##crmdatafatcacrs cr
 -----Join for EntityTaxCodeCountryISO using CountryReference
LEFT JOIN [SQLUAT].[DataServices].FATCA.CountryReference etc
    ON UPPER(etc.Country) = UPPER(LTRIM(RTRIM(cr.[EntityCountryJurisdictionName])))

-- Join for Ind_TaxCodeCountryISO using CountryReference
LEFT JOIN [SQLUAT].[DataServices].FATCA.CountryReference itc
    ON UPPER(itc.Country) = UPPER(LTRIM(RTRIM(cr.[IndividualCountryJurisdictionName])))

-- Join for Residential Country using CountryReference
LEFT JOIN [SQLUAT].[DataServices].FATCA.CountryReference crf
    ON UPPER(crf.Country) = UPPER(LTRIM(RTRIM(cr.[ResidentialCountry1])))

-- Join for Postal Country using CountryReference
LEFT JOIN [SQLUAT].[DataServices].FATCA.CountryReference pf
    ON UPPER(pf.Country) = UPPER(LTRIM(RTRIM(cr.[PostalCountry2])))

-- Join for Country of Birth using CountryReference
LEFT JOIN [SQLUAT].[DataServices].FATCA.CountryReference cb
    ON UPPER(cb.Country) = UPPER(LTRIM(RTRIM(ISNULL(cr.[CountryofBirthIdName], ''))))





----checke data indeed corelly turen to short iso code, NULL is XX, the blan kvalue is deliberate fro the Individua ltype account becasue they should have the Entoity Level TIN reported any way
--select DISTINCT TOP 1000
--[EntityCountryJurisdictionName],
--[IndividualCountryJurisdictionName],
--EntityTaxCodeCountryISOShort,
--Ind_TaxCodeCountryISOShort
--FROM
-- ##crmdatafatcacrsiso
--WHERE 
----Ind_TaxCodeCountryISOShort = 'XX' OR
--EntityTaxCodeCountryISOShort = 'XX'
--AND EntityCountryJurisdictionName !=''





----
-- Output FATCA.Stage_crmdatafatcacrs_jf : Create the Staging Table
-- Step 6.1: Create or Truncate the Staging Table

-- Drop the staging table if it exists
IF OBJECT_ID('FATCA.Stage_crmdatafatcacrs_jf', 'U') IS NOT NULL
BEGIN
    DROP TABLE FATCA.Stage_crmdatafatcacrs_jf;
END

-- Create the staging table with the same schema as ##crmdatafatcacrs but no data
SELECT TOP 0 *
INTO FATCA.Stage_crmdatafatcacrs_jf
FROM ##crmdatafatcacrsiso;

-- Step 6.2: Insert Data into the Staging Table
INSERT INTO FATCA.Stage_crmdatafatcacrs_jf
SELECT *
FROM ##crmdatafatcacrsiso; -- 5741 Rows







------## testing adn validation for step 6
----SELECT 
----    Regime,
----    COUNT(*) AS RecordCount
----FROM ##crmdatafatcacrs
----GROUP BY Regime;

-------For checkin and validate data
--Select 
--cdfc.AccountType,
--cdfc.EntityName,
--    cdfc.PortfolioNo,
--    cdfc.PortfolioServiceLevelName,
--	cdfc.dsl_RoleTypeIdName,
--    cdfc.IndividualName,
--	cdfc.CountryofTaxResidency,
--	cdfc.CountryofBirthIdName,
--	cdfc.cip_Identification,
--	cdfc.IndividualIDTypeName,
--	cdfc.Ind_TaxCodeCountryISO,
-- -- Construct a narrative to help developers understand the data
--    (ISNULL(cdfc.IndividualName, '') 
--	+' Tax Resident of ('+ cdfc.CountryofTaxResidency + ' );'
--	+  ' Born in ('+ cdfc.CountryofBirthIdName  + ' );'
--	+ ' is the (' + ISNULL(cdfc.dsl_RoleTypeIdName, '') + ' );'
--    + ' of the (' + LOWER(ISNULL(cdfc.AccountType, '')) + ' ) (' + ISNULL(cdfc.EntityName, '') + ' );'
--    + ' and reports for (' + ISNULL(cdfc.TaxRegime, '')+ ' );'
--	+' TIN IS ' + ISNULL(cdfc.cip_Identification, '') + ' ' + ISNULL(cdfc.IndividualIDTypeName, '') + ' ' + ISNULL(cdfc.Ind_TaxCodeCountryISO, ''))
--	 AS Narrative

--FROM ##crmdatafatcacrs cdfc
--where 
--cdfc.AccountType ='Multiple Tins Individual'
--AND EntityName = 'Mrs Catherine Marie Rey-Herme Cousins'
--AND IndividualName = 'Catherine Marie Rey-Herme Cousins'
--cdfc.AccountType ='Layered Entity'


--cdfc.EntityName
-- these are the 12 uses cases with complex strutured eneity walk through with Lynley, seems all from CRS
--IN('Waterview Superannuation Fund',
--'The Von Oertzen Family Trust',
--'Sylvan Trust - Australia',
--'Spandou Trust',
--'Barraclough Enterprises Limited',
--'Seidenstücker Family Trust',
--'Marion Williams Superannuation Fund',
--'Johnstone Hurst Superannuation Fund',
--'L W Haddrell Family Trust',
--'Hot Chilliz Superannuation Fund',
--'John Hepworth Superannuation Fund'
--)

