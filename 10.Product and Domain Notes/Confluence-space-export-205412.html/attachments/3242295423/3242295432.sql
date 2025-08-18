-- backgroud : We got diffenet wasy to send out the Contracts Notes (Some sort of legal trade documetns shoing how much people buy what)
-- Some are post and some are emails 


DECLARE @StartDate DATE= '2025-01-01';
DECLARE @EndDate DATE= '2025-06-30';

SELECT DISTINCT
	  cs.ID,
       cs.EqContractID Contract,
	  cs.Media,
       cs.Status Email,
       cs.Created TimeCreated,
       c.LedgerID AccountNumber,
	   c.QtyPrinted,
       cm.ShortName ClientName,
       es.SecCode SecurityCode,
       es.ExchangeID Exchange

FROM ace.dbo.CdsContractSent cs -- Chelmer Document Service (CDS)
     JOIN ace.dbo.EqContracts c ON c.ID = cs.EqContractID
     JOIN ace.dbo.EqExchSec es ON es.SecurityID = c.EqSecurityID
                                 AND es.ExchangeID = c.ExchangeID
     JOIN ace.dbo.StClients_Master cm ON cm.LedgerID = c.LedgerID
	
WHERE 1=1
	 --AND cs.Status IN('SENT','DECLINED')
	 AND Media = 'P' -- meaning Postal
	 AND CAST(cs.Created AS DATE) BETWEEN @StartDate AND  @EndDate


	 --AND c.LedgerID = 'EWPUBLICTRST'
	-- AND c.LedgerID = '231391' -- Wellington Free Ambulance Serv -- Advisor SWAT_BES2
	--AND c.LedgerID = '677557' --POST JOINT_ADJM FOR Q2 21	Peek Family Trust
ORDER BY cs.Created DESC

--[dbo].[CdsRpRequests]


--select * from CdsContractSent where Created >= GETDATE ()-1 and Status <> 'ACCEPTED' --on AACDATAQRY

--Alternative status are SENT and DECLINED