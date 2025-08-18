SELECT DISTINCT 
       advisor.AdvisorID,
	   a.dsl_PrimaryAdviserIdName,
       --advisor.AdvisorName,

       sm.Value                                AS TradingEntityType,
       a.dsl_TotalHoldingsValue                AS TE_HoldingsValue,
       a.dsl_PortfolioSearchingIDs             AS TE_AllPortfolioIDs,
       a.Name                                  AS EntityName,
       a.dsl_HighestPSLIdName                  AS TE_HighestPSL,
       a.dsl_ClosedDate                        AS TE_ClosedDate,
       a.StateCode                             AS TE_Statecode,-- 1 = inactive ; 0 = active

       ps.dsl_PortfolioIdName                  AS TE_PortfolioId,

       /* ──────── NEW aggregated column ──────── */
       (SELECT STUFF((
                SELECT DISTINCT
                       ', ' + ps2.dsl_PortfolioServiceLevelName
                FROM   CRM_MSCRM.dbo.dsl_portfolioservice ps2
                WHERE  ps2.dsl_PortfolioIdName = ps.dsl_PortfolioIdName
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 2, '')
       )                                        AS PortfolioServiceLevelList
       --/* keep the single value if you still need it */
       --ps.dsl_PortfolioServiceLevelName         AS TE_PortfolioServiceLevel,

       --ps.statecode                           AS  PS_StateCode,-- 1 = inactive ; 0 = active
       --psu.Value                               AS PortfolioServiceStatus,
       --ps.dsl_CloseDate                        AS PS_CloseDate, -- this colum ncasuing duplciates beascue some accoutn ope nand closed multiple times
       --ps.dsl_InceptionDate                    AS PS_InceptionDate
FROM   CRM_MSCRM.dbo.Account a
INNER JOIN (
           -- Subquery to retrieve active advisor details
        SELECT 
            acc.dsl_name AS AdvisorID,         -- Adviser ID from commission code
            su.FullName AS AdvisorName,          -- Adviser’s full name
            su.InternalEMailAddress AS Email,    -- Adviser's email address
            LOWER(REPLACE(su.DomainName, 'AACRAIGS\\', '')) AS ID,  -- Cleaned adviser domain
            su.SystemUserId AS Individual       -- Unique system user ID (GUID)
        FROM 
            CRM_MSCRM.dbo.dsl_advisercommissioncode acc
        INNER JOIN 
            CRM_MSCRM.dbo.dsl_advisercommissionlink acl ON acl.dsl_AdvisersId = acc.dsl_advisercommissioncodeId
        INNER JOIN 
            CRM_MSCRM.dbo.SystemUser su ON su.SystemUserId = acl.dsl_Adviser
        WHERE 
            acc.dsl_Retired = 0                       -- Exclude retired advisers
            AND acl.statecode = 0                     -- Active adviser commission link
            AND acc.statecode = 0                     -- Active adviser commission code
          --  AND acc.dsl_name <> 'HEADOFFICE'          -- Exclude pseudo-adviser "HEADOFFICE"
) advisor
       ON advisor.AdvisorID   = a.dsl_AdviserCommisionCodeIdName
      AND advisor.Individual = a.dsl_PrimaryAdviserId
     -- AND a.StateCode        = 0                            -- include all accounts
JOIN  CRM_MSCRM.dbo.dsl_portfolioservice ps
       ON ps.dsl_TradingEntityId = a.AccountId
      --AND ps.statecode          = 1
LEFT JOIN CRM_MSCRM.dbo.StringMap st
       ON st.AttributeValue  = a.StateCode
      AND st.AttributeName   = 'statecode'
      AND st.ObjectTypeCode  = 1
LEFT JOIN CRM_MSCRM.dbo.StringMap sm
       ON sm.AttributeValue = a.dsl_TradingEntityType
      AND sm.AttributeName  = 'dsl_tradingentitytype'
LEFT JOIN CRM_MSCRM.dbo.StringMap psu
       ON psu.AttributeValue = ps.dsl_PortfolioServiceStatus
      AND psu.AttributeName  = 'dsl_PortfolioServiceStatus'
      AND psu.ObjectTypeCode = 10042
-- additional WHERE conditions here if needed
WHERE ps.dsl_PortfolioIdName IS NOT NULL
AND 
ps.dsl_PortfolioIdName IN ('OOTGARBT',
'OORBT',
'231391',
'634316',
'672304',
'608813',
'668570',
'255144',
'641069',
'562385',
'270986'
)
