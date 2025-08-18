--Purpose of this :
-- it is used to deal wit hAdvisor code mismatch with CRM and ACE, ACE need to handle the advisor code by filter on sourceID = 'EQ' AND Status = 'A'

-- this part is from CRM

;WITH CRM AS(
    SELECT DISTINCT
	   dsl_PortfolioIdName COLLATE DATABASE_DEFAULT AccountID,
	   LTRIM(RTRIM(ps.dsl_AdviserCommissionCodeName)) COLLATE DATABASE_DEFAULT AdvisorID
    FROM 
	   [Dynamics].[CRM_MSCRM].[dbo].[dsl_portfolioservice] ps
    WHERE 
	   statecode = 0
	   AND ps.dsl_PortfolioServiceStatus <> 860910002 
)

-- below part is from the ACE database
,ACE AS (
    SELECT DISTINCT
	   AccountID COLLATE DATABASE_DEFAULT AccountID,
	   LTRIM(RTRIM(AdvisorID)) COLLATE DATABASE_DEFAULT AdvisorID
    FROM [AACARPTSRV].ace.dbo.StClientAdvisor 
    WHERE SourceID = 'EQ'
		AND Status = 'A'
)
SELECT 
--a.AccountID,
DISTINCT
a.AdvisorID ACEAdviserCode,c.AdvisorID CRMAdviserCode 
FROM ACE a LEFT JOIN CRM c ON a.AdvisorID<>c.AdvisorID AND a.AccountID=c.AccountID 
WHERE 
--c.AccountID IS NOT NULL
c.AccountID = '100029'
ORDER BY 1


--JOIN CTE crm ON ace.AccountID=crm.AccountID AND ace.AdvisorID=crm.AdvisorID


	 /*
SELECT dsl_PortfolioIdName,
       ps.dsl_AdviserCommissionCodeName,
       ps.dsl_PortfolioServiceStatus
FROM dsl_portfolioservice ps
WHERE statecode = 0
      AND ps.dsl_PortfolioServiceStatus <> 860910002 
--ORDER BY 1;

--SELECT TOP 10 *
--FROM StringMap s
--WHERE AttributeName = 'dsl_PortfolioServiceStatus';
*/


