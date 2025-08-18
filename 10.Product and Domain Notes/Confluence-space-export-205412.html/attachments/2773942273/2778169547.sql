--Final for CRS Out put from Step 8 


---Step 8 bring in the Account incomes details by Each portfolio No. (now the Data for TINs had beome column based)>> For CRS set

-- FATCA and CRS Account Details >> it provide income details , Interest, balance and their dividend
IF OBJECT_ID('tempdb..##CRSAccountDetails') IS NOT NULL
    DROP TABLE ##CRSAccountDetails;
-- Bring in the Income details ( please be really careful if you tu nthe scrtips in UAT server the balacne would alwasy comes back to 0)
WITH cte_income
     AS (
	 -- the is the Set A for income details for AND c.PortfolioServiceLevelName = 'Cash Management' only
	 SELECT tm.AccountNumber AS PortfolioNo, 
                c.PortfolioServiceLevelName, 
                CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalCMGross] + tm.[TotalTDInterestGross] + tm.[TotalTDAI]), 0), 0) AS Interest, 
                CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalTDIncAI] + tm.[TotalCMBalance]), 0), 0) AS Balance, 
                CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalCSLDivGross]), 0), 0) AS Dividend
         FROM
		 -- main table from FATCA.Stage_CRSPivotedData_jf
         (  -- this is to remove duplicate
             SELECT DISTINCT 
                    fpd.PortfolioNo, 
                    fpd.PortfolioServiceLevelName
             FROM [SQLUAT].[DataServices].FATCA.Stage_CRSPivotedData_jf  fpd
         ) c
		 -- tmpHoldingsPreload this table contain pre-load holdings data from data services , materialised table from CIP tab model

         JOIN [SQLCIP].Dataservices.[dbo].[tmpHoldingsPreload] tm ON tm.AccountNumber COLLATE DATABASE_DEFAULT = c.[PortfolioNo] COLLATE DATABASE_DEFAULT
                                                            AND c.PortfolioServiceLevelName = 'Cash Management'  -- only bring in the cash management data

         --and tm.ServiceLevel=c.PortfolioServiceLevelName
         GROUP BY tm.AccountNumber, 
                  c.PortfolioServiceLevelName




         UNION

		 -- the is the Set B for income details for portfolio that not in ('Cash Management', 'Craigs Kiwisaver', 'Quaystreet Kiwisaver Scheme', 'mySTART', 'SuperSTART', 'Craigs Super')
         SELECT tm.AccountNumber AS PortfolioNo, 
                c.PortfolioServiceLevelName,

				-- created 'Interest' column
                CASE
                    WHEN c.PortfolioServiceLevelName NOT IN('Cash Management', 'Craigs Kiwisaver', 'Quaystreet Kiwisaver Scheme', 'mySTART', 'SuperSTART', 'Craigs Super') --CSL
                    THEN CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalCSLIntGross]), 0), 0)
                    ELSE CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalSTARTIntGross]), 0), 0) --Other
                END AS Interest,
				--
				-- created 'Balance' column
                CASE
                    WHEN c.PortfolioServiceLevelName NOT IN('Cash Management', 'Craigs Kiwisaver', 'Quaystreet Kiwisaver Scheme', 'mySTART', 'SuperSTART', 'Craigs Super') --CSL
                    THEN CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.TotalHolding), 0), 0)
                    ELSE CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.TotalHolding), 0), 0) --Other
                END AS Balance,


				-- created 'Dividend' column
                CASE
                    WHEN c.PortfolioServiceLevelName NOT IN('Cash Management', 'Craigs Kiwisaver', 'Quaystreet Kiwisaver Scheme', 'mySTART', 'SuperSTART', 'Craigs Super') --CSL
                    THEN CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalSTARTDivGross]), 0), 0)
                    ELSE CONVERT(NUMERIC(20, 0), ROUND(SUM(tm.[TotalSTARTDivGross]), 0), 0) --Other
                END AS Dividend

       -- main table from FATCA.Stage_CRSPivotedData_jf fpd
         FROM
         (
             SELECT DISTINCT 
                    PortfolioNo, 
                    PortfolioServiceLevelName
             FROM [SQLUAT].[DataServices].FATCA.Stage_CRSPivotedData_jf  fpd

         ) c
         JOIN [SQLCIP].Dataservices.[dbo].[tmpHoldingsPreload] tm ON tm.AccountNumber COLLATE DATABASE_DEFAULT = c.[PortfolioNo] COLLATE DATABASE_DEFAULT

                                                            AND tm.ServiceLevelShortName COLLATE DATABASE_DEFAULT = c.PortfolioServiceLevelName COLLATE DATABASE_DEFAULT
															-- this is to match with the tmphoidling service short name with PortfolioServiceLevelName

         GROUP BY tm.AccountNumber, 
                  c.PortfolioServiceLevelName
				  
				  )

   -- End of the cte_income

   SELECT 
			
            fpd.AccountID AS 'ee_uniqueID', 
			fpd.IndividualId AS 'IndividualId',


            --'1' AS 'client_id', 

            fpd.TradingEntityType, 
			-- Date Filtering (for testing purposes, hardcoded dates)
			-- Uncomment and set variables if needed
			-- DECLARE @PeriodStartDate DATETIME = '2024-04-01';  -- Period start date
			-- DECLARE @PeriodEndDate DATETIME = '2025-03-31';    -- Period end date
			-- DECLARE @rptYear INT = YEAR(@PeriodEndDate);
			-- DECLARE @TRReportingDate DATETIME = '2025-09-29';  -- Reporting End Date

			CONVERT(VARCHAR, '2025-03-31', 101) AS 'actiondate',
            --CONVERT(VARCHAR, @PeriodEndDate, 101) AS 'actiondate',

            fpd.Regime AS 'regime_id', 

            --'' AS 'subdivision_id',

            fpd.[PortfolioNo] AS 'Account Number',

            fpd.PortfolioServiceLevelName,

            CASE
                WHEN fpd.PortfolioServiceLevelName = 'Cash Management'
                THEN 'CCM'
                WHEN fpd.PortfolioServiceLevelName = 'myStart'
                THEN 'CIP'
                WHEN fpd.PortfolioServiceLevelName IN('PAS', 'IAS', 'MPS', 'DIMS - Personalised', 'Standard Broking Service')
                THEN 'CSL'
                WHEN fpd.PortfolioServiceLevelName = 'Craigs Super'
                THEN 'CS'
                WHEN fpd.PortfolioServiceLevelName = 'superStart'
                THEN 'SS'
                ELSE 'Other'
            END AS ReportingEntityType, 

            --0 AS 'ac_type', 

            '' AS 'Account Number Type', 

            --'' AS 'type', 

            'NZD' AS 'currency', -- This is an Important field all the Hoidl indgata we pulled are in NZD 

            CASE
                WHEN(fpd.ClosureDate != ''
                     OR fpd.ClosureDate IS NOT NULL)
                    AND fpd.PortfolioServiceStatus NOT IN('Open', 'Pending closure')
                THEN 0
                ELSE ISNULL(ROUND(i.balance, 2), 0)
            END AS 'balance', 

            ISNULL(i.dividend, 0) AS 'dividends', 

            '' AS 'grossprocredem', 

            ISNULL(i.interest, 0) AS 'interest', 

            ai.agg_balance AS 'Aggregate Account Balance', 
            ai.agg_interest AS 'Aggregate Account Interest', 
            ai.agg_dividends AS 'Aggregate Account Dividends', 


			-- commeted them out due to these coulms seems not used i nthe final out put, keep it here still, it might be due to CRS tempalte changes
            --'' AS 'other', 
            --'' AS 'payment_currency_1', 
            --'' AS 'payment_type_1', 
            --'' AS 'payment_amount_1', 
            --'' AS 'payment_currency_2', 
            --'' AS 'payment_type_2', 
            --'' AS 'payment_amount_2', 
            --'' AS 'payment_currency_3', 
            --'' AS 'payment_type_3', 
            --'' AS 'payment_amount_3', 
            --'' AS 'payment_currency_4', 
            --'' AS 'payment_type_4', 
            --'' AS 'payment_amount_4', 
            --'' AS 'payment_currency_5', 
            --'' AS 'payment_type_5', 
            --'' AS 'payment_amount_5', 
            --'' AS 'payment_currency_6', 
            --'' AS 'payment_type_6', 
            --'' AS 'payment_amount_6', 
            --'' AS 'payment_currency_7', 
            --'' AS 'payment_type_7', 
            --'' AS 'payment_amount_7', 
            --'' AS 'payment_currency_8', 
            --'' AS 'payment_type_8', 
            --'' AS 'payment_amount_8', 
            --'' AS 'payment_currency_9', 
            --'' AS 'payment_type_9', 
            --'' AS 'payment_amount_9', 
            --'' AS 'payment_currency_10', 
            --'' AS 'payment_type_10', 
            --'' AS 'payment_amount_10',

            CASE
                WHEN i.balance + i.dividend + i.interest <> 0
                THEN 0
                ELSE 1
            END AS 'Non Reportable', 

            '' AS 'Dormant Account', -- CRS field This is an optional field to indicate if the account is dormant or not. If Dormant, enter "True" in this field. Otherwise, leave blank.

			--- for the Account Description-Undocumented CRS column
            CASE
                WHEN fpd.Regime IN('CRS', 'FATCA_CRS')
                     AND fpd.CRSCert != 'Documented'
                     AND fpd.[dsl_inceptiondate] > '2017-7-1'
                     AND ISNULL(CONVERT(NUMERIC(20, 2), i.balance, 2), 0) > 250000
                     AND fpd.[TradingEntityType] NOT IN('Individual', 'Joint', 'Minor Under 18 yrs')
                THEN 'True'
                WHEN fpd.Regime IN('CRS', 'FATCA_CRS')
                     AND fpd.CRSCert != 'Documented'
                     AND fpd.[dsl_inceptiondate] > '2017-7-1'
                     AND fpd.[TradingEntityType] IN('Individual', 'Joint', 'Minor Under 18 yrs')
                THEN 'True'
                ELSE ''
            END AS 'Undocumented', 

			-- commeted them out due to these coulms seems not used i nthe final out put, keep it here still, it might be due to CRS tempalte changes
            --'' AS 'pool', 
            --'' AS 'pool_count', 
            --'' AS 'pool_type', 
            --'' AS 'pool_report_messagerefid', 
            --'' AS 'pool_report_docrefid', 


            ISNULL(CASE
                       WHEN fpd.ClosureDate IS NOT NULL
                            AND fpd.PortfolioServiceStatus NOT IN('Open', 'Pending closure')
                       THEN CONVERT(VARCHAR, fpd.ClosureDate, 101)
                       ELSE NULL
                   END, '') AS 'Closure Date', 


            fpd.[dsl_inceptiondate] AS 'InceptionDate', 
            fpd.[CRSCert]
            --fpd.[AccountType] AS 'AccountHolder'

     INTO ##CRSAccountDetails
     
	 FROM [SQLUAT].[DataServices].FATCA.Stage_CRSPivotedData_jf fpd
          LEFT JOIN cte_income i ON i.PortfolioNo COLLATE DATABASE_DEFAULT = fpd.PortfolioNo COLLATE DATABASE_DEFAULT
                                    AND i.PortfolioServiceLevelName = fpd.PortfolioServiceLevelName
          
		  LEFT JOIN
     (
         SELECT PortfolioNo, 
                SUM(balance) AS agg_balance, 
                SUM(interest) AS agg_interest, 
                SUM(dividend) AS agg_dividends
         FROM cte_income
         GROUP BY PortfolioNo
     ) ai ON ai.PortfolioNo COLLATE DATABASE_DEFAULT = fpd.PortfolioNo COLLATE DATABASE_DEFAULT-- Aggregated income field 


	 --Select * from
	 --##CRSAccountDetails


	 ----Step 9: this step is to consolidted the Original sctips Step 8 and Step 9 (whic hout put the Final CRS sleetion with 140 columns), in origina lscrtitps the yused a T2 mechanism to Sperate out the dirty data
	 -- but in mysctips i alreay habndled the ditrty dat in step 1 to 6, i am sure the code is valid, but keep in mind that in the futreu the users might put in even more dirty data might break the code.
	 --this is not really what we coudl control, we could make sure the code is logcially sound, but we can't juts handle every dirty data, this is just the reality.


	 -- Step 9.1: CRS Final Select (In Anease's original scrtips it is Step 8)

IF OBJECT_ID('tempdb..##crsfinalselect') IS NOT NULL
    DROP TABLE ##crsfinalselect;

-- Final CRS Data Select with Simplified Logic
SELECT 
    -- -------------------------------
    -- 1. Operation and Reporting Details
    -- -------------------------------
    
    'N' AS 'Operation Type', -- Set to 'N' for New File as per OECD CRS v3.19 requirement
    'NZ' AS 'Reporting Jurisdiction', -- Hardcoded to New Zealand (NZ)
    
    -- Concatenate AccountID and PortfolioNo to create a unique Recipient ID
    (CONVERT(VARCHAR(MAX), ah.[AccountID]) + CONVERT(VARCHAR(MAX), ah.[PortfolioNo])) AS 'Recipient ID',
    
    -- -------------------------------
    -- 2. Reportable Account Type (CRS Type)
    -- -------------------------------
    
    -- Define 'Reportable Account Type' based on AccountType and TradingEntityType
    CASE
        -- CRS103: Passive Non-Financial Entity that is a CRS Reportable Person.
        WHEN cp.[AccountType]IN ('Layered Entity', 'Normal Entity')
             AND cp.TradingEntityType NOT IN ('Individual', 'Joint', 'Minor Under 18 yrs')
        THEN '4'
        
        ---- CRS102: CRS Reportable Person (Individual)
        WHEN ah.[AccountType] IN ('Single TIN Individual', 'Multiple TINs Individual') 
             AND ah.TradingEntityType IN ('Individual', 'Joint', 'Minor Under 18 yrs') 
        THEN '2'
        
        -- Handle unexpected cases
        ELSE 'ERROR'
    END AS 'Reportable Account Type',
    
    ---- -------------------------------
    ---- 3. Filer / Sponsored Entity Information
    ---- -------------------------------
    
    -- Concatenate ReportingEntityType with '_CRS' to form the short name (e.g., CSL_CRS)
    CAST(ad.ReportingEntityType AS VARCHAR(10)) + '_CRS' AS 'Filer / Sponsored Entity Short Name',
    
    -- -------------------------------
    -- 4. Account Number Details
    -- -------------------------------
    
    ad.[Account Number] AS 'Account Number', -- Portfolio number
    ad.[Account Number Type] AS 'Account Number Type', -- Typically blank unless specified
    
    -- -------------------------------
    -- 5. Portfolio Service Level Information
    -- -------------------------------
    
    ad.PortfolioServiceLevelName AS 'PortfolioServiceLevelName', -- Not directly reported for CRS
    ad.ReportingEntityType, -- Not directly reported for CRS
    
    -- -------------------------------
    -- 6. Account Descriptions and Statuses
    -- -------------------------------
    
    ad.Undocumented AS 'Account Description-Undocumented', -- Indicates if account is undocumented
    
    -- Determine if the account is closed based on Closure Date and Portfolio Service Status
    CASE
        WHEN ISDATE(ad.[Closure Date]) = 1 THEN
            CASE
                WHEN CONVERT(DATETIME, ad.[Closure Date]) < GETDATE() THEN 'True'
                ELSE ''
            END
        ELSE ''
    END AS 'Account Description-Closed',
    
    ad.[Dormant Account] AS 'Account Description-Dormant', -- Currently blank; not required for OECD
    
    -- -------------------------------
    -- 7. Account Holder Information and TINs, need to consider entity TINs or Individual TINs
    -- -------------------------------
    
    -- Tax Jurisdictions (Up to 5)
	CASE WHEN cp.[AccountType] IN ('Layered Entity', 'Normal Entity')
	     THEN cp.[EntityTaxCodeCountryISOShort]
	ELSE ah.TaxCountry1 
	END AS 'Account Holder Tax Jurisdiction',

    ISNULL(ah.TaxCountry2, '') AS 'Account Holder Tax Jurisdiction 2',
    ISNULL(ah.TaxCountry3, '') AS 'Account Holder Tax Jurisdiction 3',
    ISNULL(ah.TaxCountry4, '') AS 'Account Holder Tax Jurisdiction 4',
    ISNULL(ah.TaxCountry5, '') AS 'Account Holder Tax Jurisdiction 5',
    
    -- Tax Identification Numbers (Up to 5)
	CASE WHEN ah.[AccountType] IN ('Layered Entity', 'Normal Entity')
	     THEN ah.[EntityTIN]
	ELSE ah.TIN1 
	END AS 'Account Holder IN',

    ISNULL(ah.TIN2, '') AS 'Account Holder IN 2',
    ISNULL(ah.TIN3, '') AS 'Account Holder IN 3',
    ISNULL(ah.TIN4, '') AS 'Account Holder IN 4',
    ISNULL(ah.TIN5, '') AS 'Account Holder IN 5',
    
    -- -------------------------------
    -- 8. Account Holder IN Type
    -- -------------------------------
    
    -- Populate 'Account Holder IN Type' only for Entity Account Holders (Reportable Account Type 4)
    CASE 
        WHEN ah.AccountType IN ('Layered Entity', 'Normal Entity') 
        THEN 'TIN' -- Since NZ uses Tax File Number (TFN) as TIN
        ELSE ''
    END AS 'Account Holder IN Type',
    
    -- Leave additional IN Type fields empty as only one TIN type is used
    CONVERT(VARCHAR(50), '') AS 'Account Holder IN Type 2',
    CONVERT(VARCHAR(50), '') AS 'Account Holder IN Type 3',
    CONVERT(VARCHAR(50), '') AS 'Account Holder IN Type 4',
    CONVERT(VARCHAR(50), '') AS 'Account Holder IN Type 5',
    
    -- -------------------------------
    -- 9. Issued By Country Codes
    -- -------------------------------
    
    -- Primary Issuing Country Code
    CASE WHEN cp.[AccountType] IN ('Layered Entity', 'Normal Entity')
	     THEN cp.[EntityTaxCodeCountryISOShort]
	ELSE ah.TaxCountry1  
	END AS 'Account Holder IN Issued By Country Code',
    
    -- Issuing Country Code 2 with conditional logic
    CASE
        WHEN ah.TaxCountry2 = ah.TaxCountry1 AND ah.TIN2 = ah.TIN1 THEN ''
        ELSE ah.TaxCountry2
    END AS 'Account Holder IN Issued By Country Code 2',
    
    -- Issuing Country Code 3 with conditional logic
    CASE
        WHEN ah.TaxCountry3 = ah.TaxCountry1 AND ah.TIN3 = ah.TIN1 THEN ''
        WHEN ah.TaxCountry3 = ah.TaxCountry2 AND ah.TIN3 = ah.TIN2 THEN ''
        ELSE ah.TaxCountry3
    END AS 'Account Holder IN Issued By Country Code 3',
    
    -- Issuing Country Code 4 with conditional logic
    CASE
        WHEN ah.TaxCountry4 = ah.TaxCountry1 AND ah.TIN4 = ah.TIN1 THEN ''
        WHEN ah.TaxCountry4 = ah.TaxCountry2 AND ah.TIN4 = ah.TIN2 THEN ''
        WHEN ah.TaxCountry4 = ah.TaxCountry3 AND ah.TIN4 = ah.TIN3 THEN ''
        ELSE ah.TaxCountry4
    END AS 'Account Holder IN Issued By Country Code 4',
    
    -- Issuing Country Code 5 with conditional logic
    CASE
        WHEN ah.TaxCountry5 = ah.TaxCountry1 AND ah.TIN5 = ah.TIN1 THEN ''
        WHEN ah.TaxCountry5 = ah.TaxCountry2 AND ah.TIN5 = ah.TIN2 THEN ''
        WHEN ah.TaxCountry5 = ah.TaxCountry3 AND ah.TIN5 = ah.TIN3 THEN ''
        WHEN ah.TaxCountry5 = ah.TaxCountry4 AND ah.TIN5 = ah.TIN4 THEN ''
        ELSE ah.TaxCountry5
    END AS 'Account Holder IN Issued By Country Code 5',
    
    -- -------------------------------
    -- 10. Account Holder Organization Details
    -- -------------------------------
    
	CONVERT(VARCHAR(50), '') AS 'Account Holder Name Type (Direct Individuals and Organizations)', 
    -- Name of the organization if the account holder is an entity
    CASE
        WHEN ah.AccountType IN ('Layered Entity', 'Normal Entity')
        THEN ah.[EntityName]
        ELSE ''
    END AS 'Account Holder Organization Name',
    
    ---- Leave additional organization-related fields empty
    CONVERT(VARCHAR(50), '') AS 'Account Holder Organization Name Type',
    CONVERT(VARCHAR(50), '') AS 'Account Holder Preceding Title',
    CONVERT(VARCHAR(50), '') AS 'Account Holder Title',
    
    ---- -------------------------------
    ---- 11. Account Holder Personal Details
    ---- -------------------------------
    
    -- Individual Account Holder's First Name
    ah.FirstName AS 'Account Holder First Name', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder First Name Type',
    
    -- Individual Account Holder's Middle Name
    ah.MiddleName AS 'Account Holder Middle Name', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Middle Name Type',
    
    -- Individual Account Holder's Last Name
    ah.LastName AS 'Account Holder Last Name', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Last Name Type',
    
    -- Leave additional personal name fields empty
    CONVERT(VARCHAR(50), '') AS 'Account Holder Name Prefix', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Name Prefix Type',  
    CONVERT(VARCHAR(50), '') AS 'Account Holder Generation Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Suffix', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder General Suffix', 
    
    ---- -------------------------------
    ---- 12. Account Holder Address Details
    ---- -------------------------------
    
    ISNULL(ah.[Res Country Code], '') AS 'Account Holder Address Country',

	 CONVERT(VARCHAR(50), '') AS 'Account Holder Address Type', 
    
    -- Concatenate residential address lines into a single free-format address
    ah.[ResidentialAddressLine1] + ' ' + 
    ah.[ResidentialAddressLine2] + ' ' + 
    ah.[ResidentialAddressLine3] + ' ' + 
    ah.[ResidentialCity] + ' ' + 
    ah.[ResidentialPostalCode] AS 'Account Holder Address Free', 
    
    ---- Fixed Address Components
    CONVERT(VARCHAR(50), '')  AS 'Account Holder Fixed Street', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed Building Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed Suite Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed Floor Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed District Name', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed Post Office Box', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed Postal Code', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed City', 
    CONVERT(VARCHAR(50), '') AS 'Account Holder Fixed Subentity', 
    
    -- Date of Birth
    ISNULL(CONVERT(VARCHAR, ah.[DOB], 101), '') AS 'Account Holder Birth Date',  
    
    -- Leave non-CRS related fields empty
    CONVERT(VARCHAR(50), '') AS 'Nationality', 
    CONVERT(VARCHAR(50), '') AS 'Country of Birth', 
    CONVERT(VARCHAR(50), '') AS 'POB City', 
    CONVERT(VARCHAR(50), '') AS 'POB CitySubentity', 
    CONVERT(VARCHAR(50), '') AS 'POB FormerCountryName', 
    
    -- -------------------------------
    -- 13. Controlling Person Information
    -- -------------------------------
    
    -- Controlling Person Type from CP mapping table
    ISNULL(cp.[CP Value], '') AS 'Controlling person Type',
    
    -- -------------------------------
    -- 14. Controlling Person Tax Details
    -- -------------------------------
    
    -- Primary Controlling Person Tax Country Code with fallback to Residential Country Code
    CASE
        WHEN ISNULL(cp.TaxCountry1 COLLATE DATABASE_DEFAULT, '') = ''
        THEN ISNULL(cp.[Res Country Code] COLLATE DATABASE_DEFAULT, '')
        ELSE ISNULL(cp.TaxCountry1 COLLATE DATABASE_DEFAULT, '')
    END AS 'Controlling person Tax Country Code', -- Should be 2-digit ISO code
    
     ----Additional Controlling Person Tax Country Codes (2-5)
    ISNULL(cp.TaxCountry2, '') AS 'Controlling person Tax Country Code 2', 
    ISNULL(cp.TaxCountry3, '') AS 'Controlling person Tax Country Code 3', 
    ISNULL(cp.taxcountry4, '') AS 'Controlling Person Tax Country Code 4', 
    ISNULL(cp.taxcountry5, '') AS 'Controlling Person Tax Country Code 5', 
    
    ---- Controlling Person TINs (1-5)
    ISNULL(cp.TIN1, '') AS 'Controlling person TIN', 
    ISNULL(cp.TIN2, '') AS 'Controlling person TIN 2', 
    ISNULL(cp.TIN3, '') AS 'Controlling person TIN 3', 
    ISNULL(cp.TIN4, '') AS 'Controlling person TIN 4', 
    ISNULL(cp.TIN5, '') AS 'Controlling person TIN 5', 
    
    ---- Issued By Country Codes for Controlling Person TINs (1-5)
    ISNULL(cp.TaxCountry1, '') AS 'Controlling Person TIN Issued By', 
    ISNULL(cp.TaxCountry2, '') AS 'Controlling Person TIN Issued By 2', 
    ISNULL(cp.TaxCountry3, '') AS 'Controlling Person TIN Issued By 3', 
    ISNULL(cp.TaxCountry4, '') AS 'Controlling Person TIN Issued By 4', 
    ISNULL(cp.TaxCountry5, '') AS 'Controlling Person TIN Issued By 5', 
    
    -- -------------------------------
    -- 15. Controlling Person Personal Details
    -- -------------------------------
    
    -- Leave additional controlling person name fields empty
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Name Type', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Preceding Title', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Title', 
    
    -- Controlling Person's First and Middle Names
    ISNULL(cp.FirstName, '') AS 'Controlling Person First Name', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person First Name Type', 
    ISNULL(cp.MiddleName, '') AS 'Controlling Person Middle Name', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Middle Name Type', 
    
    ----Leave additional controlling person name fields empty
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Name Prefix', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Name Prefix Type', 
    ISNULL(cp.LastName, '') AS 'Controlling Person Last Name', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Last Name Type', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Generation Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Suffix', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person General Suffix', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Address Type', 
    
    -- Controlling Person Address Details
    ISNULL(cp.[Res Country Code], '') AS 'Controlling Person Address Country Code', 
    
    -- Concatenate controlling person residential address lines into a single free-format address
    cp.[ResidentialAddressLine1] + ' ' + 
    cp.[ResidentialAddressLine2] + ' ' + 
    cp.[ResidentialAddressLine3] + ' ' + 
    cp.[ResidentialCity] + ' ' + 
    cp.[ResidentialPostalCode] AS 'Controlling Person Address Free',

   -- -- Fixed Address Components for Controlling Person
    CONVERT(VARCHAR(50), '')  AS 'Controlling Person Fixed Street', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed Building Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed Suite Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed Floor Identifier', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed District Name', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed Post Office Box', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed Postal Code', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed City', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Fixed Subentity', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Nationality', 

    ISNULL(CONVERT(VARCHAR, cp.[DOB], 101), '') AS 'Controlling Person Birth Date', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person POB City', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person POB CitySubentity', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person Country of Birth', 
    CONVERT(VARCHAR(50), '') AS 'Controlling Person POB FormerCountryName',

    -- -------------------------------
    -- 16. Financial Information
    -- -------------------------------
    
    -- Account Balance: Set to 0 if balance is negative or zero
    CASE 
        WHEN ad.balance <= 0 THEN 0 
        ELSE ad.balance 
    END AS 'Account Balance', 
    
    ad.currency AS 'Account Currency', -- ISO currency code >> in our cotnext the yare all NZD
    
    -- Interest: Set to 0 if interest is negative or zero
    CASE 
        WHEN ad.interest <= 0 THEN 0 
        ELSE ad.interest 
    END AS 'Interest',
    
    ad.currency AS 'Interest Currency Code', -- ISO currency code for Interest
	-- Dividentd related
	CASE
        WHEN ad.dividends <= 0
        THEN 0
        ELSE ad.dividends
    END AS 'Dividends', 
    ad.currency AS 'Dividends Currency Code',
    CASE
        WHEN ad.grossprocredem <= 0  -- empty data should be 0
        THEN 0
        ELSE ad.grossprocredem
    END AS 'Gross Proceeds_Redemptions', 

    ad.currency AS 'Gross Proceeds_Redemptions Currency Code',

	-- -------------------------------
    -- 17. Other requiered  Information
    -- -------------------------------

	CONVERT(VARCHAR(50), '') AS 'Other', 
    CONVERT(VARCHAR(50), '') AS 'Other Currency Code', 
    CONVERT(VARCHAR(50), '') AS 'Line of Business', 
    CONVERT(VARCHAR(50), '') AS 'Level 1', 
    CONVERT(VARCHAR(50), '') AS 'Level 2', 

	-- new added column based on the V3.19 OECD CRS requirements
	CONVERT(VARCHAR(50), '')  as [Business Unit],
    CONVERT(VARCHAR(50), '')  as [Business Sub Unit],
    CONVERT(VARCHAR(50), '')  as [Business Sub Unit 2],

	--the empty field for people to fill in if needed
    CONVERT(VARCHAR(50), '') AS 'Custom 1', 
    CONVERT(VARCHAR(50), '') AS 'Custom 2', 
    CONVERT(VARCHAR(50), '') AS 'Custom 3', 
    CONVERT(VARCHAR(50), '') AS 'Custom 4', 
    CONVERT(VARCHAR(50), '') AS 'Custom 5', 
    CONVERT(VARCHAR(50), '') AS 'Custom 6', 
    CONVERT(VARCHAR(50), '') AS 'Custom 7', 
    CONVERT(VARCHAR(50), '') AS 'Custom 8', 
    CONVERT(VARCHAR(50), '') AS 'Custom 9', 
    CONVERT(VARCHAR(50), '') AS 'Custom 10', 
    CONVERT(VARCHAR(50), '') AS 'Custom 11', 
    CONVERT(VARCHAR(50), '') AS 'Custom 12', 
    CONVERT(VARCHAR(50), '') AS 'Custom 13'
 
INTO ##crsfinalselect

FROM ##CRSAccountDetails ad -- Account Details (like Money related)
-- why jointhe same tabel twice here >> it is becasue the CRS data was reprot in the same row but the ygot two differe sections (Account hodler sections have about 40 columns , and then Cotnrollin geprosn had about 40 columns , then i is the Finacial detaso lsection have soem columns, becasur the set up we join the table twice to bring in details that reprot in the coreect setiosn for CRS)

-- JOIN Operations
-- Join with Account Holder Data (Individuals and Entities)
LEFT JOIN FATCA.Stage_CRSPivotedData_jf ah 
    ON 
	ad.[ee_uniqueID] = ah.[AccountID]
	AND ad.IndividualId = ah.IndividualId
	AND ad.[Account Number] = ah.[PortfolioNo] 
    AND ad.PortfolioServiceLevelName = ah.PortfolioServiceLevelName
    -- AND ah.AccountType IN ('Multiple TINs Individual', 'Single TIN Individual')
    -- Note: This join brings in Account Holder details for Individuals and Entities
    
-- Join with Controlling Person Data (Entities Only)
LEFT JOIN FATCA.Stage_CRSPivotedData_jf cp 
    ON 
	ad.[ee_uniqueID] = cp.[AccountID]
	AND ad.IndividualId = cp.IndividualId
	AND ad.[Account Number] = cp.[PortfolioNo] 
    AND ad.PortfolioServiceLevelName = cp.PortfolioServiceLevelName
    AND cp.AccountType IN ('Layered Entity', 'Normal Entity')

    -- Note: This join brings in Controlling Person details for Entity Account Holder
-- -------------------------------
    -- 18. Filter using Aneases Original data Filter
    -- -------------------------------
WHERE 1=1 
	-- Excldue test or hosue account
    AND ad.[Account Number] NOT LIKE '%dummy%' 
    AND ad.[Account Number] NOT LIKE 'OO%' 
    AND ad.[Account Number] NOT LIKE 'OM%' 

	-- Exclude things that look dodgy (ad.[Account Balance] + ad.Interest + ad.Dividends + ad.[Gross Proceeds_Redemptions]  >> mean no money in all areas >> this would only works in PROD server
   AND 
   (CAST(ad.balance AS INT) + CAST(ad.interest AS INT) + CAST(ad.dividends AS INT) <> 0)




	--Select * from ##crsfinalselect--

-- below uodate statement are fro mthe original locgsi not sure if i should use them


UPDATE ##crsfinalselect
  SET 
      [Account Holder Tax Jurisdiction 4] = ''
WHERE [Account Holder Tax Jurisdiction 4] = [Account Holder Tax Jurisdiction 5];


UPDATE ##crsfinalselect
  SET 
      [Controlling Person Tax Country Code 4] = ''
WHERE [Controlling Person Tax Country Code 4] = [Controlling Person Tax Country Code 5];

UPDATE ##crsfinalselect
  SET 
      [Account Holder Tax Jurisdiction] = [Account Holder Tax Jurisdiction 5]
WHERE [Account Holder Tax Jurisdiction] = ''
      AND [Account Holder Tax Jurisdiction 5] <> '';

UPDATE ##crsfinalselect
  SET 
      [Account Holder Tax Jurisdiction 5] = ''
WHERE [Account Holder Tax Jurisdiction] = [Account Holder Tax Jurisdiction 5];

UPDATE ##crsfinalselect
  SET 
      [Account Holder IN Issued By Country Code] = [Account Holder Tax Jurisdiction]
WHERE [Account Holder IN Issued By Country Code] = ''
      AND [Account Holder IN] <> '';

UPDATE ##crsfinalselect
  SET 
      [Account Holder IN Issued By Country Code 2] = [Account Holder Tax Jurisdiction 2]
WHERE [Account Holder IN Issued By Country Code 2] = ''
      AND [Account Holder IN 2] <> '';

UPDATE ##crsfinalselect
  SET 
      [Account Holder IN Issued By Country Code 3] = [Account Holder Tax Jurisdiction 3]
WHERE [Account Holder IN Issued By Country Code 3] = ''
      AND [Account Holder IN 3] <> '';

UPDATE ##crsfinalselect
  SET 
      [Account Holder IN Issued By Country Code 4] = [Account Holder Tax Jurisdiction 4]
WHERE [Account Holder IN Issued By Country Code 4] = ''
      AND [Account Holder IN 4] <> '';

UPDATE ##crsfinalselect
  SET 
      [Account Holder IN Issued By Country Code 5] = [Account Holder Tax Jurisdiction 5]
WHERE ISNULL([Account Holder IN Issued By Country Code 5], '') = ''
      AND ISNULL([Account Holder IN 5], '') <> '';



    -- -------------------------------
    -- Verfification Section
    -- -------------------------------


---------------Cehcke why the joisn is not correct in this case
--Select TOP 10 *
  
--  FROM FATCA.Stage_CRSPivotedData_jf cp 
--	LEFT JOIN  ##CRSAccountDetails ad 
--	ON 
--	ad.[ee_uniqueID] = cp.[AccountID]
--	--AND ad.[ee_uniqueID] = cp.[IndividualId] 

--	AND ad.[Account Number] = cp.[PortfolioNo] 
--    AND ad.PortfolioServiceLevelName = cp.PortfolioServiceLevelName
--    AND cp.AccountType IN ('Layered Entity', 'Normal Entity')-- Account Details (like Money related)
	
--	WHERE ad.[ee_uniqueID] IS NOT NULL
	


	----Verify the ##crsfinalselect data quality see if it make sense

	--Select Top 1000*
	--from ##crsfinalselect
	--where [Reportable Account Type] = '4'


	----- verify why there are duplicates i nthe Portolio ID
	--Select Top 1000*
	--from
	--FATCA.Stage_CRSPivotedData_jf cp 
 --   where AccountType IN ('Layered Entity', 'Normal Entity')
	--AND AccountID = '8E93893B-CFFD-E411-9400-005056A36616'
	--AND IndividualId = 'A5676D99-AA6F-4F30-A85B-2D5F43453F85'--'21985E4D-9177-EA11-A2C0-00505681265F'
	--AND PortfolioNo = '603625' --'639111'
	--AND PortfolioServiceLevelName = 'DIMS - Personalised'

	--i could confie, fro mthe data struture only 
	--AccountID + IndividualId + PortfolioNo + PortfolioServiceLevelName would produce a truly Unique combinatio nas the data set


	---find if entity got multiple Entit yTIN, i could confirm Entity TIn only have one TIN per entity

--	SELECT 
--    cp.IndividualId, 
--	--cp.PortfolioNo,
--    COUNT(DISTINCT cp.EntityTIN) AS DistinctEntityTINCount
--FROM 
--    FATCA.Stage_CRSPivotedData_jf cp
--WHERE 
--    cp.AccountType IN ('Layered Entity', 'Normal Entity')
--GROUP BY 
--    cp.IndividualId
--	--cp.PortfolioNo
--HAVING 
--    COUNT(DISTINCT cp.EntityTIN) > 1







-- Step 9.2: Insert CRS Data into Final Table for Submission
--delete from [FATCA].[CRS_Final_Output_AccountHolders_ControllingPerson_Financeinfo_jf] where ReportingYear=@rptYear
--drop table [FATCA].[CRS_Final_Output_AccountHolders_ControllingPerson_Financeinfo_jf]
--insert into [FATCA].[CRS_Final_Output_AccountHolders_ControllingPerson_Financeinfo_jf]

    -- Uncomment and set variables if needed
    -- DECLARE @PeriodStartDate DATETIME = '2024-04-01';  -- Period start date
    -- DECLARE @PeriodEndDate DATETIME = '2025-03-31';    -- Period end date
    -- DECLARE @rptYear INT = YEAR(@PeriodEndDate);
    -- DECLARE @TRReportingDate DATETIME = '2025-09-29';  -- Reporting End Date
select 

--General info section ---
'2025' as ReportingYear,

GetDate() as LastUpdated,
ReportingEntityType,
[Operation Type],
[Reporting Jurisdiction],
newid() [Recipient ID],
[Reportable Account Type],
[Filer / Sponsored Entity Short Name],
[Account Number],
[Account Number Type],
[Account Description-Undocumented],
[Account Description-Closed],
[Account Description-Dormant],

--Account Holder section ---
[Account Holder Tax Jurisdiction],
[Account Holder Tax Jurisdiction 2],
[Account Holder Tax Jurisdiction 3],
[Account Holder Tax Jurisdiction 4],
[Account Holder Tax Jurisdiction 5],
[Account Holder IN],
[Account Holder IN 2],
[Account Holder IN 3],
[Account Holder IN 4],
[Account Holder IN 5],
[Account Holder IN Type],
[Account Holder IN Type 2],
[Account Holder IN Type 3],
[Account Holder IN Type 4],
[Account Holder IN Type 5],
[Account Holder IN Issued By Country Code],
[Account Holder IN Issued By Country Code 2],
[Account Holder IN Issued By Country Code 3],
[Account Holder IN Issued By Country Code 4],
[Account Holder IN Issued By Country Code 5],
[Account Holder Name Type (Direct Individuals and Organizations)],
[Account Holder Organization Name],
[Account Holder Organization Name Type],
[Account Holder Preceding Title],
[Account Holder Title],
[Account Holder First Name],
[Account Holder First Name Type],
[Account Holder Middle Name],
[Account Holder Middle Name Type],
[Account Holder Name Prefix],
[Account Holder Name Prefix Type],

FATCA.CleanAccents([Account Holder Last Name]) AS [Account Holder Last Name],

[Account Holder Last Name Type],
[Account Holder Generation Identifier],
[Account Holder Suffix],
[Account Holder General Suffix],
[Account Holder Address Type],
[Account Holder Address Country],
FATCA.CleanAccents([Account Holder Address Free]) As [Account Holder Address Free],

[Account Holder Fixed Street],
[Account Holder Fixed Building Identifier],
[Account Holder Fixed Suite Identifier],
[Account Holder Fixed Floor Identifier],
[Account Holder Fixed District Name],
[Account Holder Fixed Post Office Box],
[Account Holder Fixed Postal Code],
FATCA.CleanAccents([Account Holder Fixed City]) as [Account Holder Fixed City],
[Account Holder Fixed Subentity],
[Account Holder Birth Date],
[Nationality],
[Country of Birth],
[POB City],
[POB CitySubentity],
[POB FormerCountryName],

--Controlling person section ---
[Controlling person Type],
[Controlling person Tax Country Code],
[Controlling person Tax Country Code 2],
[Controlling person Tax Country Code 3],
[Controlling person Tax Country Code 4],
[Controlling person Tax Country Code 5],
[Controlling person TIN],
[Controlling person TIN 2],
[Controlling person TIN 3],
[Controlling person TIN 4],
[Controlling person TIN 5],
[Controlling Person TIN Issued By],
[Controlling Person TIN Issued By 2],
[Controlling Person TIN Issued By 3],
[Controlling Person TIN Issued By 4],
[Controlling Person TIN Issued By 5],
[Controlling Person Name Type],
[Controlling Person Preceding Title],
[Controlling Person Title],
[Controlling Person First Name],
[Controlling Person First Name Type],
[Controlling Person Middle Name],
[Controlling Person Middle Name Type],
[Controlling Person Name Prefix],
[Controlling Person Name Prefix Type],

FATCA.CleanAccents([Controlling Person Last Name]) AS [Controlling Person Last Name],

[Controlling Person Last Name Type],
[Controlling Person Generation Identifier],
[Controlling Person Suffix],
[Controlling Person General Suffix],
[Controlling Person Address Type],
[Controlling Person Address Country Code],

FATCA.CleanAccents([Controlling Person Address Free]) AS [Controlling Person Address Free],

[Controlling Person Fixed Street],
[Controlling Person Fixed Building Identifier],
[Controlling Person Fixed Suite Identifier],
[Controlling Person Fixed Floor Identifier],
[Controlling Person Fixed District Name],
[Controlling Person Fixed Post Office Box],
[Controlling Person Fixed Postal Code],

FATCA.CleanAccents([Controlling Person Fixed City]) AS [Controlling Person Fixed City],

[Controlling Person Fixed Subentity],
[Controlling Person Nationality],
[Controlling Person Birth Date],
[Controlling Person POB City],
[Controlling Person POB CitySubentity],
[Controlling Person Country of Birth],
[Controlling Person POB FormerCountryName],

--Finance Information section ---
[Account Balance],
[Account Currency],
[Interest],
[Interest Currency Code],
[Dividends],
[Dividends Currency Code],
[Gross Proceeds_Redemptions],
[Gross Proceeds_Redemptions Currency Code],
[Other],
[Other Currency Code],
[Line of Business],
[Level 1],
[Level 2],
-- new added column based on the V3.19 OECD CRS requirements
[Business Unit],
[Business Sub Unit],
[Business Sub Unit 2],

--Custom Field Section
[Custom 1],
[Custom 2],
[Custom 3],
[Custom 4],
[Custom 5],
[Custom 6],
[Custom 7],
[Custom 8],
[Custom 9],
[Custom 10],
[Custom 11],
[Custom 12],
[Custom 13]
into [FATCA].[CRS_Final_Output_AccountHolders_ControllingPerson_Financeinfo_jf]
from ##crsfinalselect  -- out put from step 8


--Select TOP 0 *
--INTO [FATCA].[CRS_Final_Output_AccountHolders_ControllingPerson_Financeinfo_jf]
--from ##crsfinalselect



select * from [FATCA].[CRS_Final_Output_AccountHolders_ControllingPerson_Financeinfo_jf]
WHERE [Reportable Account Type] = '2'



-- please note that if out want to test and make sense of data do not waster your tiems with these 143 Columns, take a few steps back to FATCA.Stage_crmdatafatcacrs_jf,
--it would be much more easier for yo uto test