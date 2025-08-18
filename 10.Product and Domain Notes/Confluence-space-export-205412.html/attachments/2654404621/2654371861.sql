/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [FirmID]
      ,[ID]
      ,[AltKey]
      ,[Name]
      ,[StBranchID]
      ,[Status]
      ,[OperatorID]
  FROM [ace].[dbo].[StAdvisors]



  Select TOP 100 *
  FROM [dbo].[StClientKeys] ck
  WHERE LedgerID = '100029'

   Select TOP 100 *
  FROM [dbo].[StClients_Master] cm
    WHERE LedgerID = '100029'




	-- this show one client have two advisor code
  Select TOP 100 *
  FROM
  [dbo].[StClientAdvisor] ca
  --left join dbo.StAdvisorSource aso ON ca.AdvisorID=aso.AdvisorID

  WHERE AccountID = '100047'--'100029'



  --------------

SELECT DISTINCT
	   AccountID COLLATE DATABASE_DEFAULT AccountID,
	   LTRIM(RTRIM(AdvisorID)) COLLATE DATABASE_DEFAULT AdvisorID
    FROM ace.dbo.StClientAdvisor 
    WHERE SourceID = 'EQ'
		AND Status = 'A'
		AND AccountID = --'101004'