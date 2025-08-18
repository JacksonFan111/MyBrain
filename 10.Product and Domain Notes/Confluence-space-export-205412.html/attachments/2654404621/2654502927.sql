SELECT DISTINCT TOP 10
	   dsl_PortfolioIdName COLLATE DATABASE_DEFAULT AccountID,
	   LTRIM(RTRIM(ps.dsl_AdviserCommissionCodeName)) COLLATE DATABASE_DEFAULT AdvisorID,
	   statecode,
	   ps.dsl_PortfolioServiceStatus
    FROM 
	   [CRM_MSCRM].[dbo].[dsl_portfolioservice] ps
    WHERE 
	1=1
	AND dsl_PortfolioIdName = '101004'--'609416'

	--AND   statecode = 0 
	--AND ps.dsl_PortfolioServiceStatus <> 860910002 

	-- State code is like a slowly changing dimension >. adn then PortfolioServiceStatus is the actual drop down boxes for the portfolio services staus like (Opened, Closed etc.)

	SELECT DISTINCT TOP 10 *
	ps.dsl_portfolioservicestatus,
	sm.AttributeName,
	sm.ObjectTypeCode
	a.accountid,
	ps.dsl_tradingentityid,
	CRMFIFS.AttributeName,
	a.dsl_FIFStatus,
	TET.AttributeName,
	a.dsl_TradingEntityType,
	dsl_PortfolioServiceNo

	FROM  [CRM_MSCRM].[dbo].[dsl_portfolioservice] ps
			INNER JOIN [CRM_MSCRM].[dbo].StringMap sm
			ON sm.AttributeValue = ps.dsl_portfolioservicestatus
			AND sm.AttributeName = 'dsl_portfolioservicestatus'
			AND sm.ObjectTypeCode=10042 -- although not required but good to always use ObjectTypeCode check while using StringMap table


			INNER JOIN [CRM_MSCRM].[dbo].account a
			on a.accountid = ps.dsl_tradingentityid

			INNER JOIN [CRM_MSCRM].[dbo].[StringMap] CRMFIFS	WITH (NOLOCK)
			ON	CRMFIFS.AttributeName = 'dsl_FIFStatus' AND CRMFIFS.ObjectTypeCode =1
			AND a.dsl_FIFStatus = CRMFIFS.AttributeValue


			INNER JOIN [CRM_MSCRM].[dbo].[StringMap] TET	WITH (NOLOCK)
			ON	TET.AttributeName = 'dsl_TradingEntityType' AND TET.ObjectTypeCode =1
			AND a.dsl_TradingEntityType = TET.AttributeValue
			WHERE sm.AttributeValue =  860910000
			and dsl_PortfolioServiceNo in ('218526','190595','106932', '340007', '635981')