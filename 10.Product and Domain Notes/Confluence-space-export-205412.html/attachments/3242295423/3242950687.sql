--Server = aacarptsrv
--DB = Ace
--related report = [Contract Notes Sent Yesterday]

DECLARE @StartDate DATE= '2025-06-30';
DECLARE @Days INT=30


SET @Days = ABS(@Days) * -1


;WITH CTE AS(
    

SELECT DISTINCT
	  
	  cs.ID,
       cs.EqContractID Contract,
	  cs.Media,
       cs.Status Email,
       cs.Created TimeCreated,
       c.LedgerID AccountNumber,
       cm.ShortName ClientName,
       es.SecCode SecurityCode,
       es.ExchangeID Exchange

FROM ace.dbo.CdsContractSent cs
     JOIN ace.dbo.EqContracts c ON c.ID = cs.EqContractID
     JOIN ace.dbo.EqExchSec es ON es.SecurityID = c.EqSecurityID
                                  AND es.ExchangeID = c.ExchangeID
     JOIN ace.dbo.StClients_Master cm ON cm.LedgerID = c.LedgerID
WHERE 1=1
	 AND cs.Status IN('SENT','DECLINED')
	 AND CAST(cs.Created AS DATE) BETWEEN DATEADD(day,@Days,@StartDate) AND DATEADD(day, 1, @StartDate)

--UNION SELECT 999999,999999,'E','SENT','2018-04-28 10:37:10.090','99999','The Sheather Family Trust','XYZ','XYZ'
)
,DONE AS(

SELECT DISTINCT
	
	  cs.ID,
	  ct.Contract,
       --cs.EqContractID Contract,
	  cs.Media,
       cs.Status Email,
       cs.Created TimeCreated,
       c.LedgerID AccountNumber,
       cm.ShortName ClientName,
       es.SecCode SecurityCode,
       es.ExchangeID Exchange

FROM CTE ct
	LEFT JOIN ace.dbo.CdsContractSent cs ON cs.EqContractID=ct.Contract
     LEFT JOIN ace.dbo.EqContracts c ON c.ID = cs.EqContractID
     LEFT JOIN ace.dbo.EqExchSec es ON es.SecurityID = c.EqSecurityID
                                  AND es.ExchangeID = c.ExchangeID
     LEFT JOIN ace.dbo.StClients_Master cm ON cm.LedgerID = c.LedgerID
WHERE 1=1
	 AND cs.Status NOT IN('SENT','DECLINED')
	 AND CAST(cs.Created AS DATE) BETWEEN DATEADD(day,@Days,@StartDate) AND DATEADD(day, 1, @StartDate)

--UNION SELECT 555555,555555,NULL,NULL,NULL,NULL,NULL,NULL,NULL

),Missing AS(

SELECT * FROM CTE ct WHERE ct.Contract NOT IN (SELECT Contract FROM DONE)


)
, Final AS(
SELECT 1 AS Type,* FROM CTE ct WHERE ct.Contract NOT IN (SELECT Contract FROM Missing)
UNION
SELECT 2 AS Type,* FROM DONE
UNION
SELECT 3 AS Type,* FROM Missing
)
SELECT * FROM Final
ORDER BY 
CASE WHEN Type=3 THEN 1 ELSE 2 END,
Contract,TimeCreated