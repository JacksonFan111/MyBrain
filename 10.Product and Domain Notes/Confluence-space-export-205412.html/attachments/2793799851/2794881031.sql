/*
Author: Chris Andrews
reviwer Person : Jackson FAN
Date: 18/09/2013


Reviewed Date: 23/10/2024
Details:
	This report is used to reconcile used assets in AP with active assets
	in ARM to ensure the asset sectors are in alignment
*/


-- fro new testing use [KAPSQLDAT-DEV01].[AACPR_Restored]


--Data Source=SVSQLCRM\SQLCRM;Initial Catalog=AACPR >> use reportuser >. this seems to be an Old Server


--ARM (Asset Register Maintenance (ARM) this is from theLinked server = [AACARPTSRV],  Database =  fusion
--New server = SQLCIP , New Destination DB = [AACPR] this is the Correct DB.  >> ARM (Asset Register Maintenance (ARM)

--PR Reporting Service Holdings:
--PR clients - source system will be AACPR

----PR Reporting Service Transactions:
--PR clients - 
--source system will be AACPR

--Cache/Staging ex Source
--To reduce the impact on production systems, we take a copy of AACPR prod and restore to KAPSQLDAT-DEV01 (AACPR_Restored). 
--A snapshot/restore of AACPR on the Dev server. This provides us with a point-in-time dataset to query that doesn’t change due to BAU; we can refresh by arrangement when desired/required.

-- I am guessing the PR Reporting Service (Backend is the AP) >> This relates to AXYS/CRM PR reporting. FOR AP uses >>  [KAPSQLDAT-DEV01].[AACPR_Restored]

-- so i think the scritps is comappring Fuiso ndataabse with the [AACPR] datasbe and che kfor the SEC code if they had mistached


--If the #ARM temp table exists drop it
if object_id('tempdb..#ARM') is not null
drop table #ARM
if object_id('tempdb..#Both') is not null
drop table #Both

--Declare the parameters for the openquery	
DECLARE		@OPENQUERY nvarchar(4000)
DECLARE		@TSQL nvarchar(4000)
DECLARE		@LinkedServer nvarchar(4000)
DECLARE		@TSQL_A nvarchar(4000)
	
SET @LinkedServer = 'AACARPTSRV'
SET @OPENQUERY = 'SELECT * FROM OPENQUERY('+ @LinkedServer + ','''
	
SET @TSQL_A = '
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
set nocount on
set rowcount 0

SELECT i.isin,
	isnull(das.SectorCode,''''NONE'''') COLLATE DATABASE_DEFAULT SectorCode,
	isnull(das.SectorName,''''NONE'''') COLLATE DATABASE_DEFAULT SectorName,
	isnull(a.code,''''NONE'''') COLLATE DATABASE_DEFAULT SecCode,
	isnull(e.code,''''NONE'''') COLLATE DATABASE_DEFAULT ExchangeCode ,
	isnull(i.assetCode,''''NONE'''') COLLATE DATABASE_DEFAULT AssetCode
FROM fusion.dbo.Asset a
join fusion.dbo.Issue i on i.issueID = a.issueID
join fusion.dbo.Exchange e on e.exchangeID = a.exchangeID
left join
	(
		Select g2.code SectorCode,g2.name SectorName, i.issueID
		from fusion.dbo.Issue i
		join fusion.dbo.IssueReportingClass irc on irc.issueID = i.issueID and  getdate() between isnull(irc.effectiveStartDate,''''1799-12-31'''') and isnull(irc.effectiveEndDate,''''2099-12-31'''')
		join fusion.dbo.Glt g1 on g1.gltID = irc.rptClassTypeID and  g1.className = ''''DAS''''
		join fusion.dbo.Glt g2 on g2.gltID = irc.[rptClassValueID] and g1.code = ''''DefAssSec''''
	) das on das.issueID = i.issueID 
where a.status = 1 and i.status = ''''A''''
'
CREATE TABLE #ARM(
ISIN varchar(255),
SectorCode varchar(255),
SectorName varchar(255),
SecCode varchar(255),
ExchangeCode varchar(255),
AssetCode varchar(255))

insert into #ARM(ISIN,SectorCode,SectorName,SecCode,ExchangeCode,AssetCode)

exec(@OPENQUERY+@TSQL_A + ''')') 
;

--The below Common table expression finds used AP assets, and does a translation of
--the exchange code to match ARM >> data source is AACPR >> Portfolio reporting database >>  [KAPSQLDAT-DEV01].[AACPR_Restored]

with CTE_AP (APSecCode,APExchangeCode,APSectorCode,APSectorName)
as
(
Select  distinct
a.SecurityCode as SecCode,
case 
	when m.Code = 'NZX' then 'NZSE' 
	when lower(m.Description) like '%temporary%' then 'Unlisted'
else m.Code end as Exchange,
ass.Code as AssetSectorCode,
ass.Description as AssetSectorDescription
from 
--[svsqlcrm\sqlcrm].[AACPR].[dbo].TransactionHolding th
 [svsqlcrm\sqlcrm].[AACPR].[dbo].Asset a --on a.AssetID = th.AssetID
join [svsqlcrm\sqlcrm].[AACPR].[dbo].AssetSector ass on ass.AssetSectorID = a.AssetSectorID
join [svsqlcrm\sqlcrm].[AACPR].[dbo].Market m on m.MarketID = a.MarketID
where th.StatusID = 1
),

--To be consistent the #ARM table is added into a common table expression
CTE_ARM (ISIN,ARMSectorCode,ARMSectorName,ARMSecCode,ARMExchangeCode,ARMAssetCode)
as
(
Select * from #ARM
),

--Common table expression to join the two systems
CTE_Both (ARMAssetCode,
	ARMSecCode,
	ARMExchangeCode,
	ISIN,
	APSecCode,APExchangeCode,
	ARMSectorCode,ARMSectorName,
	APSectorCode,APSectorName)
as
(
Select ARMAssetCode,
	ARMSecCode,
	ARMExchangeCode,
	ISIN,
	APSecCode,APExchangeCode,
	ARMSectorCode,ARMSectorName,
	APSectorCode,APSectorName 
from CTE_ARM ARM
full outer join CTE_AP AP on 
APExchangeCode = ARMExchangeCode
	and APSecCode = ARMSecCode
where ARMSecCode is not null and 
APSecCode is not null 
)

--Identify the assets that don't have matching sectors
Select 	*
into #Both
from CTE_Both 
where ARMSectorCode <> APSectorCode
order by ARMExchangeCode, ARMSecCode

Select 
ARMSecCode,
	ARMExchangeCode,
	ISIN,
	APSecCode,APExchangeCode,
	ARMSectorCode,ARMSectorName,
	APSectorCode,APSectorName 
from #both


