/*==============================================================================*/
--	
--	IRD Reporting Details View
--	
--	 
--	Developer:			Christopher Church
--	
--	Date:	2019-01-03
--	
--  Comment:	Details view for IRD reporting files to leverage off
--
/*==============================================================================*/

--EXEC dbo.usp_IRDReportingData

--ALTER PROCEDURE dbo.usp_IRDReportingData

--AS

--BEGIN 

UPDATE CSL.dbo.tax_IRDReportingData
SET 
	IRDStatusFlag = 0

DELETE CSL.dbo.tax_IRDReportingData
WHERE
	IRDStatusFlag = 0
	AND
	IRDRunDate = convert(date, getdate()) 
	


/*================================ Parameters ==================================*/ 



	DECLARE @ReturnPeriodBeg Date			=   DATEADD(dd,1,DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-2,Getdate())))))
	DECLARE @ReturnPeriodEnd Date			=	DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))) 

	--print @ReturnPeriodBeg
	--print @ReturnPeriodEnd

	DECLARE @RunFlag			varchar(1)		=	'O'
	
	DECLARE	@ReturnPeriodBegKey	varchar (50)	SET			@ReturnPeriodBegKey		=		convert(varchar(20),replace(@ReturnPeriodBeg,'-',''))		-- Period start date
	DECLARE	@ReturnPeriodEndKey	varchar (50)	SET			@ReturnPeriodEndKey		=		convert(varchar(20),replace(@ReturnPeriodEnd,'-',''))		-- Period end date

/*============================ Get from control table ==========================*/ 

	DECLARE @FormVersionNumber				varchar(20)			=	'0001'									
	DECLARE @ContactPersion					Varchar(20)			=	'Haley Jamieson'						
	DECLARE @ContactPersionInformation		Varchar(20)			=	'+64 7 927 7955'						
	DECLARE @DWTRate						numeric(20,6)		=	0.25
	DECLARE @PortfolioServiceLevelName		varchar(50)			=	'Standard Broking Service'

/*================================= Testing ====================================*/ 

	DECLARE @AccountsToTest					varchar(max)		=	'400001,258133,613915,190497' --'158113' --

							/*====================================================================================
							'400001'		--Company
							, '258133'		--individual	- Mr Philip Andrew Armstrong
							, '613915'		--Trust			- Muddy Bay Trust
							, '190497'		--Joint			- Mr B M & Mrs N C Adams
							=====================================================================================*/

/*================================ Distinct CRM Accounts for Individuals ==================================*/ 


	--Accounts in CSL tblTransaction for the given period
		if OBJECT_ID('tempdb..#AccountsToProcess')	is not null		drop table #AccountsToProcess

			SELECT 
				Distinct AccID 

				INTO
				--SELECT distinct AccID FROM
				#AccountsToProcess

			FROM [SQLCIP].CSL.[dbo].[tblTransaction]		

			WHERE
				ProcessDate	BETWEEN @ReturnPeriodBeg	and		@ReturnPeriodEnd
				--and
				--IncType	=	3

	--Account Data
		if OBJECT_ID('tempdb..#crmAccount') is not null drop table #crmAccount

		Select 

			 a.Name 
			,a.AccountId 
			,a.cip_OnboardingApprovalDate
			,a.dsl_CountryTrustEstablishedIdName 
			,a.dsl_tax1_CountryIdName
			,a.dsl_tax2_CountryIdName
			,a.dsl_PrimaryTaxDomicileName
			,a.dsl_Address1CountryLookupIdName
			,a.dsl_Address2CountryLookupIdName
			,a.dsl_Address3CountryLookupIdName
			,a.dsl_TradingEntityType
			,a.Telephone1 
			,a.Telephone2
			,a.Telephone3 
			,a.Address1_Line1
			,a.Address1_Line2
			,a.Address1_Line3
			,a.Address1_City
			,a.Address1_PostalCode
			,a.Address2_Line1
			,a.Address2_Line2
			,a.Address2_Line3
			,a.Address2_City
			,a.Address2_PostalCode
			,a.dsl_PassiveorActive
			,a.dsl_IRDNumber
			,a.dsl_IdentificationNumber1
			,a.dsl_IdentificationNumber2
			,a.cip_SelfCertification
			,a.StateCode
			,a.StatusCode
			,a.dsl_TradingEntityStatus
			,a.dsl_PortfolioSearchingIDs
			,a.PrimaryContactIdName
			,a.PrimaryContactId 
			,a.dsl_IndividualOwnerIdName	
			,a.dsl_IndividualOwnerId		
			,a.EmailAddress1 

		into #crmAccount 
	
		from [DynamicsPROD].[CRM_MSCRM].dbo.Account a

		--WHERE
			--a.StateCode	=	0

	--Roles
	if OBJECT_ID('tempdb..#crmdsl_roles') is not null drop table #crmdsl_roles

	Select 
	
		 r.dsl_BeneficialOwner 
		,r.dsl_RoleTypeIdName
		,r.dsl_TradingEntityId 
		,r.dsl_IndividualId
		,r.dsl_Applicant
		,r.dsl_BeneficiaryOwnership
		,r.statuscode

	into #crmdsl_roles  

	from [DynamicsPROD].[CRM_MSCRM].dbo.dsl_roles r


	--Contact
		if OBJECT_ID('tempdb..#crmContact') is not null drop table #crmContact

		Select 

			 c.ContactID 
			,c.FullName 
			,c.FirstName
			,c.MiddleName
			,c.LastName 
			,c.dsl_Address1CountryLookupIdName 
			,c.dsl_Address2CountryLookupIdName 
			,c.dsl_Address3CountryLookupIdName 
			,c.Telephone1
			,c.Telephone2 
			,c.Telephone3 
			,c.Address1_Line1
			,c.Address1_Line2
			,c.Address1_Line3
			,c.Address1_City
			,c.Address1_PostalCode
			,c.Address2_Line1
			,c.Address2_Line2
			,c.Address2_Line3
			,c.Address2_City
			,c.Address2_PostalCode
			,c.dsl_CountryofCitizenshipIdName 
			,c.dsl_CountryofTaxResidencyName 
			,c.dsl_IdentificationNumber1
			,c.dsl_IdentificationNumber2
			,c.dsl_IRDNumber
			,c.dsl_CountryOfBirthIdName
			,c.BirthDate
			,c.cip_TownCityofBirth
			,c.CustomerTypecode
			,c.Statuscode
			,c.dsl_Deceased
			,c.Statecode
			,c.dsl_Country1IdName
			,c.dsl_Country2IdName
			,c.cip_SelfCertification
			,c.dsl_CountryofResidenceIdName
			,c.EMailAddress1 
			,c.MobilePhone 
 
		 into #crmContact 
 
		--SELECT top  100000 EMailAddress1
			  --Prod: 
			  --[TGASQLPROD\TGASQLCRM].[CRM_MSCRM].dbo.Contact c
		 from	--UAT: 
				[DynamicsPROD].[CRM_MSCRM].dbo.Contact c

		 --WHERE
			--c.Statecode		=	0

	--Portfolio Service
		if OBJECT_ID('tempdb..#crmdsl_portfolioservice') is not null drop table #crmdsl_portfolioservice

		Select 

			 ps.dsl_AdviserCommissionCodeName
			,ps.dsl_PortfolioIdName
			,ps.dsl_InceptionDate
			,ps.dsl_PortfolioServiceLevelName
			,ps.dsl_CloseDate
			,ps.dsl_TradingEntityId
			,ps.dsl_PortfolioServiceStatus
			,ps.dsl_PortfolioServiceLevel
			,ps.dsl_portfolioserviceId 
			,ps.dsl_PortfolioServiceNo
			,ps.statecode
 
		 into 
		 --SELECT distinct dsl_PortfolioIdName FROM
		 #crmdsl_portfolioservice 
 
		FROM
				(
					SELECT 
						*  
					FROM  
						[DynamicsPROD].[CRM_MSCRM].dbo.dsl_portfolioService ps 
					WHERE
						--dsl_PortfolioServiceLevelName	=	'Standard Broking Service'
						--AND statecode					=	'0'
						--AND statuscode				=	'100000004' 
						--AND 
						dsl_PortfolioServiceNo		IN (SELECT AccID COLLATE DATABASE_DEFAULT FROM #AccountsToProcess) 

				) ps  



	--ID
	if OBJECT_ID('tempdb..#crmdsl_identificationitem') is not null drop table #crmdsl_identificationitem

	Select  
		 id.dsl_Individual
		,id.dsl_IDCountryofIssueName 

	into #crmdsl_identificationitem 

	from [DynamicsPROD].[CRM_MSCRM].dbo.dsl_identificationitem id



	--Stringmap
	if OBJECT_ID('tempdb..#crmStringMap') is not null drop table #crmStringMap

		Select * 

		into #crmStringMap 

		from [DynamicsPROD].[CRM_MSCRM].dbo.StringMap


	--Profile
	--if OBJECT_ID('tempdb..#crmdsl_profile') is not null drop table #crmdsl_profile

	--	Select 

	--		 p.dsl_ProfileCategoryIdName 
	--		,p.dsl_Individualid 
	--		,p.dsl_questionidName
	--		,p.dsl_AccountId

	--	into #crmdsl_profile 

	--	from [DynamicsPROD].[CRM_MSCRM].dbo.dsl_profile p


	--Country
	if OBJECT_ID('tempdb..#crmCountry') is not null drop table #crmCountry

		Select * 

		into #crmCountry 

		from [AACARPTSRV].[fusion].dbo.Country





--Temp Tables Data Collation

if OBJECT_ID('tempdb..#crmdatafatca') is not null drop table #crmdatafatca
if OBJECT_ID('tempdb..#crmdatafatca_crs') is not null drop table #crmdatafatca_crs  
IF OBJECT_ID('tempdb..#bib') IS NOT NULL DROP TABLE #bib 
IF OBJECT_ID('tempdb..#data3') IS NOT NULL DROP TABLE #data3
IF OBJECT_ID('tempdb..#data2') IS NOT NULL DROP TABLE #data2
if OBJECT_ID('tempdb..#fxNZDBalances_0') is not null drop table #fxNZDBalances_0
if OBJECT_ID('tempdb..#fxNZDBalances_1') is not null drop table #fxNZDBalances_1
if OBJECT_ID('tempdb..#AccountHolders') is not null drop table #AccountHolders
if OBJECT_ID('tempdb..#wpholdings') is not null drop table #wpholdings
if OBJECT_ID('tempdb..#fxNZDBalances') is not null drop table #fxNZDBalances
IF OBJECT_ID('tempdb..#temp_csl') IS NOT NULL DROP TABLE #temp_csl
IF OBJECT_ID('tempdb..#temp_csl1') IS NOT NULL DROP TABLE #temp_csl1
IF OBJECT_ID('tempdb..#FXRates') IS NOT NULL DROP TABLE #FXRates
IF OBJECT_ID('tempdb..#CSL_CashIncome') IS NOT NULL DROP TABLE #CSL_CashIncome
IF OBJECT_ID('tempdb..#AccountDetails') IS NOT NULL DROP TABLE #AccountDetails



--FATCA individuals


;WITH CTE as 
(

	 
	--DECLARE @ReturnPeriodEnd	Date			=	DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-1,Getdate()))))
	--DECLARE @ReturnPeriodBeg Date =  DATEADD(month, DATEDIFF(month, 0, DATEADD(mm,-11,@ReturnPeriodEnd)), 0)


	select
	'Individual'																					as 'Account Holder' 
	,c.ContactID																					as 'AccountID'
	,row_number() over(partition by c.ContactID,ps.dsl_PortfolioIdName order by a.Name)				as 'RowNUM'
	,c.FullName																						as 'Name'
	,c.FirstName																					as 'FirstName'
	,c.MiddleName																					as 'MiddleName'
	,c.LastName																						as 'LastName'
	, a.Name																						as 'Entity Name'
	, a.AccountId																					as 'EntityID'
	, sm.Value																						as 'Entity Type'
	,CASE
		WHEN 
			sm.Value  not in ('Individual','Joint','Minor Under 18 yrs') 
			and (r.dsl_BeneficialOwner = 1  
			and r.dsl_BeneficiaryOwnership > 10 
			and sm.Value = 'Company')										
																			THEN 1
		WHEN 
			sm.Value  not in ('Individual','Joint','Minor Under 18 yrs','Company') 
			and r.dsl_BeneficialOwner = 1									
																			THEN 1
		ELSE 0
	  END																							as 'Substantial Owner/Controlling Person' 
	, r.dsl_RoleTypeIdName																			as 'Role Type'
	, ps.dsl_PortfolioIdName																		as 'Portfolio No'
	, ps.dsl_InceptionDate																			as 'Inception Date'
	, a.cip_OnboardingApprovalDate																	as 'Onboarding Date'
	, ps.dsl_PortfolioServiceLevelName																as 'Portfolio Service Level'
	, smPS.Value																					as [PortfolioServiceStatus] 
	, c.dsl_Address1CountryLookupIdName																as 'Residential Country1'
	, c.dsl_Address2CountryLookupIdName																as 'Postal Country2'
	, c.dsl_Address3CountryLookupIdName																as 'Registered Office Country3'
	, c.Telephone1																					as 'Tel1'
	, c.Telephone2																					as 'Tel2'
	, c.Telephone3																					as 'Tel3'
	,ISNULL(c.Address1_Line1,'')																	as 'Residential Address_Line1'
	,ISNULL(c.Address1_Line2,'')																	as 'Residential Address_Line2'
	,ISNULL(c.Address1_Line3,'')																	as 'Residential Address_Line3'
	,ISNULL(c.Address1_City,'')																		as 'Residential City'
	,ISNULL(c.Address1_PostalCode,'')																as 'Residential PostalCode'
	,ISNULL(c.Address2_Line1,'')																	as 'Postal Address_Line1'
	,ISNULL(c.Address2_Line2,'')																	as 'Postal Address_Line2'
	,ISNULL(c.Address2_Line3,'')																	as 'Postal Address_Line3'
	,ISNULL(c.Address2_City,'')																		as 'Postal City'
	,ISNULL(c.Address2_PostalCode,'')																as 'Postal PostCode'
	,a.dsl_CountryTrustEstablishedIdName															as 'Trust Country'
	,a.dsl_tax1_CountryIdName																		as 'Org Tax Country1'
	,a.dsl_tax2_CountryIdName																		as 'Org Tax Country2'
	,a.dsl_PrimaryTaxDomicileName																	as 'Org Primary Tax Domicile'
	,a.dsl_Address1CountryLookupIdName																as 'Country of Residence'
	,c.dsl_CountryofCitizenshipIdName																as 'Country of Citizenship'
	,c.dsl_CountryofTaxResidencyName																as 'Country of Tax Residency1'
	,CASE 
		WHEN c.dsl_CountryofTaxResidencyName = 'New Zealand' THEN c.dsl_IRDNumber 
		ELSE ''
	END											as ' Tax ID 1' 
	,ISNULL(coun.isoCode,'')					as 'Tax Country 1'
	,case
		when 
			c.dsl_CountryofTaxResidencyName <> 'New Zealand' 
			and isnull(c.dsl_IRDNumber,'')	<> ''					then c.dsl_IRDNumber
		else isnull(c.dsl_IdentificationNumber1,'') end													as 'Tax ID 2'
	,case
	when 
		c.dsl_CountryofTaxResidencyName <> 'New Zealand' 
		and isnull(c.dsl_IRDNumber,'')	<> ''						then 'NZ'
	else isnull(coun1.isoCode,'') end																	as 'Tax Country 2'
	,isnull(c.dsl_IdentificationNumber2,'')																as 'Tax ID 3'
	,isnull(coun2.isoCode,'')																			as 'Tax Country 3'
	,c.dsl_IRDNumber																					as 'NZ IRD'
	,c.dsl_CountryOfBirthIdName																			as 'Country of Birth'
	, NULL																								as pc1 
	, NULL																								as pc2 
	,(convert(varchar(19),(dateadd(hour,13,c.BirthDate)),101))											as 'DOB'
	,ps.dsl_CloseDate																					as 'ClosureDate'
	,c.cip_TownCityofBirth																				as 'Town/City of Birth'
	, NULL																								as 'CRS Self Cert'
	,c.EMailAddress1																					as  EMailAddress1 
	,c.MobilePhone  																					as  MobilePhone  
	,a.PrimaryContactIdName																				as  PrimaryContactIdName
	,a.PrimaryContactId																					as  PrimaryContactId
	, CASE
			WHEN  c.ContactID = a.PrimaryContactId			THEN					'1'
			ELSE																	'2'
	  END																								as	PrimaryContactFlag
	, CASE
			WHEN	c.ContactID = a.dsl_IndividualOwnerId 
					and c.ContactID <> a.PrimaryContactId	THEN					'1'
			ELSE																	'2'
	  END																								as	IndividualAccountOrderFlag
	--, sm3.Value																							as	dsl_portfolioservicestatus
	--, @ReturnPeriodBeg																					as ReturnPeriodBeg
	--, @ReturnPeriodEnd																					as ReturnPeriodEnd
	,a.dsl_IndividualOwnerIdName																		as  IndividualOwnerIdName
	,a.dsl_IndividualOwnerId																			as  IndividualOwnerId

	from #crmContact c
	inner join #crmdsl_roles r on r.dsl_IndividualId = c.ContactId and r.statuscode = 1
	inner join #crmAccount a on a.AccountId = r.dsl_TradingEntityId
	inner join #crmdsl_portfolioservice ps on ps.dsl_TradingEntityId = a.AccountId
	--join #CSLBalances csl on csl.AccountNumber COLLATE DATABASE_DEFAULT = ps.dsl_PortfolioIdName COLLATE DATABASE_DEFAULT
	left join #crmdsl_identificationitem id on id.dsl_Individual = c.ContactId
	inner join #crmStringMap smPS on smPS.AttributeName = 'dsl_PortfolioServiceStatus' and smPS.AttributeValue = ps.dsl_PortfolioServiceStatus
	left join #crmStringMap sm on sm.AttributeValue = a.dsl_TradingEntityType and sm.AttributeName = 'dsl_tradingentitytype'
	left join #crmCountry coun  on coun.name COLLATE DATABASE_DEFAULT = c.dsl_CountryofTaxResidencyName COLLATE DATABASE_DEFAULT
	left join #crmCountry coun1  on coun1.name COLLATE DATABASE_DEFAULT = c.dsl_Country1IdName COLLATE DATABASE_DEFAULT
	left join #crmCountry coun2  on coun2.name COLLATE DATABASE_DEFAULT = c.dsl_Country2IdName COLLATE DATABASE_DEFAULT
	--left join #crmstringmap sm3 on sm3.AttributeName = 'dsl_portfolioservicestatus' and sm3.AttributeValue = ps.dsl_PortfolioServiceStatus
	left JOIN #crmstringmap sm5 ON  sm5.AttributeName = 'dsl_passiveoractive'AND sm5.AttributeValue = a.dsl_PassiveorActive
	
	--Where

		--ps.dsl_PortfolioServiceLevelName	=		@PortfolioServiceLevelName --'Standard Broking Service'
		--and 
		/* recently took out below as accounts are still having transaction well after their closed date */
			--(
			--	smPS.Value in ('Open','Pending closure') 
			--	or 
			--	(smPS.Value = 'Closed' and ps.dsl_CloseDate >= @ReturnPeriodEnd /* and ps.dsl_CloseDate < @ReturnPeriodBeg */ )
			--)
			--and (sm5.Value is null or sm5.Value != 'Active')
			--and ps.dsl_inceptiondate <= @ReturnPeriodEnd
		--and
		--sm.Value	IN		('Individual','Joint')
		--and
		--r.dsl_RoleTypeIdName	IN ('Individual','Intermediary Agent','Trustee','')
		--and 
		--ps.dsl_PortfolioIdName = '555608'


UNION


	--	DECLARE @ReturnPeriodEnd	Date			=	DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-1,Getdate()))))
	--DECLARE @ReturnPeriodBeg Date =  DATEADD(month, DATEDIFF(month, 0, DATEADD(mm,-11,@ReturnPeriodEnd)), 0)

	select 
	'Entity'																							as 'Account Holder' 
	, a.AccountID																						as 'AccountID'
	,row_number() over(partition by a.AccountID,ps.dsl_PortfolioIdName order by a.Name)					as 'RowNUM'
	, a.Name																							as 'Name'
	,''																									as 'FirstName'
	,''																									as 'MiddleName'
	,''																									as 'LastName'
	, a.Name																							as 'TE Name'
	, a.AccountId																						as 'EntityID'
	, sm.Value																							as 'Entity Type'
	, ''																								as  'Substantial Owner/Controlling Person' 
	, r.dsl_RoleTypeIdName																				as 'Role Type'
	, ps.dsl_PortfolioIdName																			as 'Portfolio No'
	, ps.dsl_InceptionDate																				as 'Inception Date'
	, a.cip_OnboardingApprovalDate																		as 'Onboarding Date'
	, ps.dsl_PortfolioServiceLevelName																	as 'Portfolio Service Level'
	, smPS.Value																						as [PortfolioServiceStatus] 
	, a.dsl_Address1CountryLookupIdName																	as 'Residential Country1'
	, a.dsl_Address2CountryLookupIdName																	as 'Postal Country2'
	, a.dsl_Address3CountryLookupIdName																	as 'Registered Office Country3'
	, a.Telephone1																						as 'Tel1'
	, a.Telephone2																						as 'Tel2'
	, a.Telephone3																						as 'Tel3'
	,ISNULL(a.Address1_Line1,'')																		as 'Residential Address_Line1'
	,ISNULL(a.Address1_Line2,'')																		as 'Residential Address_Line2'
	,ISNULL(a.Address1_Line3,'')																		as 'Residential Address_Line3'
	,ISNULL(a.Address1_City,'')																			as 'Residential City'
	,ISNULL(a.Address1_PostalCode,'')																	as 'Residential PostalCode'
	,ISNULL(a.Address2_Line1,'')																		as 'Postal Address_Line1'
	,ISNULL(a.Address2_Line2,'')																		as 'Postal Address_Line2'
	,ISNULL(a.Address2_Line3,'')																		as 'Postal Address_Line3'
	,ISNULL(a.Address2_City,'')																			as 'Postal City'
	,ISNULL(a.Address2_PostalCode,'')																	as 'Postal PostCode'
	, a.dsl_CountryTrustEstablishedIdName																as 'Trust Country'
	, a.dsl_tax1_CountryIdName																			as 'Org Tax Country1'
	, a.dsl_tax2_CountryIdName																			as 'Org Tax Country2'
	, a.dsl_PrimaryTaxDomicileName																		as 'Org Primary Tax Domicile'
	,a.dsl_Address1CountryLookupIdName																	as 'Country of Residence'
	,''																									as 'Country of Citizenship'
	,a.dsl_PrimaryTaxDomicileName																		as 'Country of Tax Residency1'
	,CASE 
		WHEN a.dsl_PrimaryTaxDomicileName = 'New Zealand'				THEN a.dsl_IRDNumber 
		ELSE ''
	END																									as ' Tax ID 1'

	,ISNULL(coun.isoCode,'')																			as 'Tax Country 1'
	,isnull(a.dsl_IdentificationNumber1,'')																as 'Tax ID 2'
	,isnull(coun1.isoCode,'')																			as 'Tax Country 2'
	,isnull(a.dsl_IdentificationNumber2,'')																as 'Tax ID 3'
	,isnull(coun2.isoCode,'')																			as 'Tax Country 3'
	,a.dsl_IRDNumber																					as 'NZ IRD'
	, ''																								as 'Country of Birth'
	, NULL																								as pc1 
	, NULL																								as pc2 
	, ''																								as  'DOB'
	, ps.dsl_CloseDate																					as 'ClosureDate'
	, ''																								as 'Town/City of Birth'
	,NULL																								as 'CRS Cert'
	,a.EmailAddress1 																					as	EMailAddress1 
	,a.Telephone1																						as	MobilePhone 
	,a.PrimaryContactIdName																				as  PrimaryContactIdName
	,a.PrimaryContactId																					as  PrimaryContactId
	, CASE
			WHEN  c.ContactID = a.PrimaryContactId THEN		'1'
			ELSE											'2'
	  END																								as	PrimaryContactFlag
	, CASE
			WHEN  c.ContactID = a.dsl_IndividualOwnerId THEN						'1'
			ELSE																	'2'
	  END																								as	IndividualAccountOrderFlag

	--, sm3.Value
	,a.dsl_IndividualOwnerIdName																		as  IndividualOwnerIdName
	,a.dsl_IndividualOwnerId																			as  IndividualOwnerId


	from #crmAccount a
	inner join #crmdsl_roles r on a.AccountId = r.dsl_TradingEntityId and r.statuscode = 1
	inner join #crmContact c on c.ContactId = r.dsl_IndividualId
	inner join #crmdsl_portfolioservice ps on ps.dsl_TradingEntityId = a.AccountId
	--join #CSLBalances csl on csl.AccountNumber COLLATE DATABASE_DEFAULT = ps.dsl_PortfolioIdName COLLATE DATABASE_DEFAULT
	left join #crmdsl_identificationitem id on id.dsl_Individual = c.ContactId
	inner join #crmStringMap smPS on smPS.AttributeName = 'dsl_PortfolioServiceStatus' and smPS.AttributeValue = ps.dsl_PortfolioServiceStatus
	left join #crmStringMap sm on sm.AttributeValue = a.dsl_TradingEntityType and sm.AttributeName = 'dsl_tradingentitytype'
	left join #crmCountry coun  on coun.name COLLATE DATABASE_DEFAULT = a.dsl_PrimaryTaxDomicileName COLLATE DATABASE_DEFAULT
	left join #crmCountry coun1  on coun1.name COLLATE DATABASE_DEFAULT = a.dsl_tax1_CountryIdName COLLATE DATABASE_DEFAULT
	left join #crmCountry coun2  on coun2.name COLLATE DATABASE_DEFAULT = a.dsl_tax2_CountryIdName COLLATE DATABASE_DEFAULT
	--left join #crmstringmap sm3 on sm3.AttributeName = 'dsl_portfolioservicestatus' and sm3.AttributeValue = ps.dsl_PortfolioServiceStatus
	--left JOIN #crmstringmap sm5 ON  sm5.AttributeName = 'dsl_passiveoractive'AND sm5.AttributeValue = a.dsl_PassiveorActive
	--where 

	--	(
	--		smPS.Value in ('Open','Pending closure') 
	--		or 
	--		(smPS.Value = 'Closed' and ps.dsl_CloseDate > @ReturnPeriodBeg and ps.dsl_CloseDate < @ReturnPeriodEnd)
	--	)
		--and 
		--(sm5.Value is null or sm5.Value != 'Active')
		--and 
		--ps.dsl_inceptiondate <= @ReturnPeriodEnd
		 
		--sm.Value	NOT IN	('Joint','Individual')--	('Company','Trust','Incorporated Entity')
		--and
			-- ps.dsl_PortfolioIdName = '555608'

)





Select * 
into #crmdatafatca
/*
SELECT * FROM #crmdatafatca
WHERE
	[Portfolio No] = '634339'
*/

from CTE
Where RowNum = 1


--Amalgamated Account Holders/Substantial Owners/Controlling Persons


if OBJECT_ID('tempdb..#crmdatafatca_crs_control') is not null drop table #crmdatafatca_crs_control


--Add the Account Holders whom are Passive NFFE's
select 
	 'Entity_N'																						as 'Account Holder' 
	,ce.EntityID																					as 'AccountID'
	,row_number() over(partition by ce.[EntityID],ce.[Portfolio No] order by ce.Name)				as 'RowNUM'
	, ce.Name																						as 'Name'
	,''																								as 'FirstName'
	,''																								as 'MiddleName'
	,''																								as 'LastName'
	, ce.[Entity Name]																				as 'Entity Name'
	, ce.EntityID																					as 'EntityID'
	, ce.[Entity Type]																				as 'Entity Type'
	, 0																								as  'Substantial Owner/Controlling Person' 
	, ce.[Role Type]																				as 'Role Type'
	, ce.[Portfolio No]																				as 'Portfolio No'
	, ce.[Inception Date]																			as 'Inception Date'
	, ce.[Onboarding Date]																			as 'Onboarding Date'
	, ce.[Portfolio Service Level]																	as 'Portfolio Service Level'
	, ce.PortfolioServiceStatus																		as [PortfolioServiceStatus]
	, a.dsl_Address1CountryLookupIdName																as 'Residential Country1'
	, a.dsl_Address2CountryLookupIdName																as 'Postal Country2'
	, a.dsl_Address3CountryLookupIdName																as 'Registered Office Country3'
	, a.Telephone1																					as 'Tel1'
	, a.Telephone2																					as 'Tel2'
	, a.Telephone3																					as 'Tel3'
	,ISNULL(a.Address1_Line1,'')																	as 'Residential Address_Line1'
	,ISNULL(a.Address1_Line2,'')																	as 'Residential Address_Line2'
	,ISNULL(a.Address1_Line3,'')																	as 'Residential Address_Line3'
	,ISNULL(a.Address1_City,'')																		as 'Residential City'
	,ISNULL(a.Address1_PostalCode,'')																as 'Residential PostalCode'
	,ISNULL(a.Address2_Line1,'')																	as 'Postal Address_Line1'
	,ISNULL(a.Address2_Line2,'')																	as 'Postal Address_Line2'
	,ISNULL(a.Address2_Line3,'')																	as 'Postal Address_Line3'
	,ISNULL(a.Address2_City,'')																		as 'Postal City'
	,ISNULL(a.Address2_PostalCode,'')																as 'Postal PostCode'
	, a.dsl_CountryTrustEstablishedIdName															as 'Trust Country'
	, a.dsl_tax1_CountryIdName																		as 'Org Tax Country1'
	, a.dsl_tax2_CountryIdName																		as 'Org Tax Country2'
	, a.dsl_PrimaryTaxDomicileName																	as 'Org Primary Tax Domicile'
	,a.dsl_Address1CountryLookupIdName																as 'Country of Residence'
	,''																								as 'Country of Citizenship'
	,a.dsl_PrimaryTaxDomicileName																	as 'Country of Tax Residency1'
	,CASE 
		WHEN a.dsl_PrimaryTaxDomicileName = 'New Zealand' THEN a.dsl_IRDNumber
		ELSE ''
		END																							as ' Tax ID 1'

	,ISNULL(coun.isoCode,'')																		as 'Tax Country 1'
	,isnull(a.dsl_IdentificationNumber1,'')															as 'Tax ID 2'
	,isnull(coun1.isoCode,'')																		as 'Tax Country 2'
	,isnull(a.dsl_IdentificationNumber2,'')															as 'Tax ID 3'
	,isnull(coun2.isoCode,'')																		as 'Tax Country 3'
	, ''																							as 'NZ IRD'
	, ''																							as 'Country of Birth'
	, ''																							as pc1 
	, ''																							as pc2 
	, DOB																							as  [DOB]
	, ce.ClosureDate																				as 'ClosureDate'
	, ''																							as 'Town/City of Birth'
	, NULL as 'CRS Self Cert'
	,ce.EMailAddress1	
	,ce.MobilePhone 
	, ce.PrimaryContactIdName	
	, ce.PrimaryContactId	
	, ce.PrimaryContactFlag
	, ce.IndividualAccountOrderFlag
	, ce.IndividualOwnerIdName	
	, ce.IndividualOwnerId		

into #crmdatafatca_crs_control

from #crmdatafatca ce
join #crmAccount a on a.AccountID = ce.EntityID
left join #crmCountry coun  on coun.name COLLATE DATABASE_DEFAULT = a.dsl_PrimaryTaxDomicileName COLLATE DATABASE_DEFAULT
left join #crmCountry coun1  on coun1.name COLLATE DATABASE_DEFAULT = a.dsl_tax1_CountryIdName COLLATE DATABASE_DEFAULT
left join #crmCountry coun2  on coun2.name COLLATE DATABASE_DEFAULT = a.dsl_tax2_CountryIdName COLLATE DATABASE_DEFAULT
Where ce.[Substantial Owner/Controlling Person] = 1 


--drop table #crmdatafatca_crs

INSERT INTO #crmdatafatca
Select * from #crmdatafatca_crs_control
Where RowNUM = 1

/*
SELECT distinct [Portfolio No] FROM #crmdatafatca
WHERE
	[Portfolio No] = '624416'
*/


--Select * from #crmdatafatca_crs

if OBJECT_ID('tempdb..#crmdatafatca_crs_final') is not null drop table #crmdatafatca_crs_final

--Clean Up Account Holders
Select row_number() over(partition by crs.[AccountID],crs.[Portfolio No],crs.[Account Holder] order by crs.Name) as 'RowNUM_1',* 
into #crmdatafatca_crs_final
from #crmdatafatca crs 



/*================================ Exchange Rate ==================================*/ 

if OBJECT_ID('tempdb..#FXRates')			is not null		drop table  #FXRates
if OBJECT_ID('tempdb..#NZD_FX')				is not null		drop table  #NZD_FX

	
	--SELECT 
	--	Convert(Date, LEFT(AsAtDateKey,4) + '-' + RIGHT(LEFT(AsAtDateKey,6),2) + '-' + RIGHT(AsAtDateKey,2))	AS AsAtDateKey
	--	, USDNZDRate
	--	, USDAUDRate

	--INTO #FXRates 
	
	--FROM
	--[SQL_BI].Datamart.[Trading].[Fact_FxRate_Daily]
	--WHERE
	--	AsAtDateKey between convert(bigint, replace(@ReturnPeriodBeg,'-','')) and  convert(bigint, replace(@ReturnPeriodEnd,'-',''))
	--	--AsAtDateKey >=  convert(bigint, replace(@ReturnPeriodBeg,'-','')) --AND @ReturnPeriodEnd 




	SELECT fx.DateKey fxdatekey,fx.fxRate 

	INTO #NZD_FX

	from [SQL_BI].Datamart.[Trading].[F_FxRate_v] fx
	join [SQL_BI].Datamart.trading.Dim_Currency c on c.CurrencyKey = fx.ToCurrencyKey
	where c.CurrencyCode = 'NZD'



	SELECT 
		left(DateKey, 4) + '-' + RIGHT(left(DateKey, 6),2) + '-' + RIGHT(DateKey, 2)  AS FXDate,
		FXRate,
		CurrencyCode

	INTO #FXRates

	FROM
	(

		select  
			fx.datekey				AS DateKey,
			NZD.fxRate/fx.fxRate	AS FXRate,
			c.CurrencyCode			AS CurrencyCode


		from #NZD_FX		NZD						
		join [SQL_BI].Datamart.[Trading].[F_FxRate_v] fx on fx.DateKey = NZD.fxdatekey
		join [SQL_BI].Datamart.trading.Dim_Currency c on c.CurrencyKey = fx.ToCurrencyKey

		union

		Select 
			fxdatekey,
			fxRate,
			'USD'
		from #NZD_FX
		--order by 1,3 desc
	) AS T

	--SELECT * FROM #FXRates  ORDER BY FXDate 

/*================================ Number of Account Holders Calculation ==================================*/ 

if OBJECT_ID('tempdb..#NoOfAccounts')			is not null		drop table  #NoOfAccounts
	
			SELECT AccID, count(1) as NoOfAccounts
			
			INTO #NoOfAccounts

			FROM
			(
			SELECT distinct AccID, FirstName
			FROM CSL.[dbo].[tblTransaction]																	trn

				LEFT JOIN #crmdatafatca 																	crm
					ON crm.[Portfolio No] COLLATE DATABASE_DEFAULT	=	trn.AccID	COLLATE DATABASE_DEFAULT

				JOIN CSL.dbo.tblIncType																inc
					ON inc.IncTypeID		=	trn.IncType 
			)
			AS T

			--WHERE 
			--	AccID	IN	(SELECT splitdata	 FROM	DataServices.dbo.fnSplitString(@AccountsToTest,','))

			GROUP BY AccID


/*================================ File Detail Generation ==================================*/ 

if OBJECT_ID('tempdb..##FileDetail')			is not null		drop table  ##FileDetail

		SELECT	

				--CRM Attributes

					crm.[Entity Type] 																			AS [RoleFlag]
					, [Account Holder]																			AS [Account Holder] 
					, CASE 
							WHEN crm.[Entity Type]  IN ('Joint','Individual') THEN		CRM.Name
							ELSE														CRM.[Entity Name]
					  END																						AS [Name] 
					, CRM.Name																					AS [Individual Name]
					, crm.[NZ IRD]																				AS [Recipient IRD number]
					, crm.[NZ IRD]																				AS [Dividend recipient IRD number]
					, crm.DOB																					AS [Date of birth]
					, ISNULL(crm.[Residential Address_Line1],'')
						+ ' ' + ISNULL(crm.[Residential Address_Line2],'')
						+ ' ' + ISNULL(crm.[Residential Address_Line3],'')
						+ ' ' + ISNULL(crm.[Residential City],'')
						+ ' ' + ISNULL(crm.[Residential Country1],'')
						+ ' ' + ISNULL(crm.[Residential PostalCode],'')
																												AS [Contact address]
					, ISOctry.isoCode																			AS [Country code]
					, EMailAddress1																				AS [Email address]
					, COALESCE(MobilePhone, Tel1)																AS [Phone number] 
					, CASE
							WHEN crm.[Entity Type]	= 'Joint'	THEN	'T'
							ELSE										'F'
					  END																						AS [Joint account or Joint investment]
					, CASE
							WHEN crm.[Entity Type]	= 'Joint'	THEN NoOfAcc.NoOfAccounts
							ELSE 1
					  END																						AS [Number of account holders]
					, 0																							AS [RWT rate]								/* TBC - Ben */

				--CSL Attributes

					, trn.Tax1Amount /* or trn.Tax1Amount, depending on calc */									AS [Total Approved issuer Levy deducted]	/* TBC - Ben */
					, trn.GrossAmount																			AS [Total Gross Earnings]
					, 
						CASE 
							WHEN trn.Tax1 = '7' THEN trn.Tax1Amount 
							ELSE 0
						END
						+
						CASE 
							WHEN trn.Tax1 = '7' THEN trn.Tax2Amount 
							ELSE 0
						END	
						+
						CASE 
							WHEN trn.Tax1 = '7' THEN trn.Tax3Amount 
							ELSE 0
						END
							/* depends on Tax1, tax2 types */ 													AS [Total resident withholding tax deducted] /* TBC - Ben */

					, 
						CASE 
							WHEN trn.Tax1 = '11' THEN trn.Tax1Amount 
							ELSE 0
						END
						+
						CASE 
							WHEN trn.Tax1 = '11' THEN trn.Tax2Amount 
							ELSE 0
						END	
						+
						CASE 
							WHEN trn.Tax1 = '11' THEN trn.Tax3Amount 
							ELSE 0
						END
							/* depends on Tax1, tax2 types */ 													AS [Total non-resident withholding tax deducted] /* TBC - Ben */
					, trn.AccID																					AS [Identifier]
					, trn.GrossAmount																			AS [Gross liable income]
					, NULL																						AS [AIL deducted]
					, CASE
							WHEN inc.Type	=	'Dividend'	THEN (ISNULL(GrossAmount,0) * ISNULL(fxr.FXRate,1))
							ELSE 0
					  END																						AS [Gross Dividend]
					, NULL																						AS [Gross dividends treated as interest]
					, CASE
							WHEN inc.Type	=	'Dividend'	THEN (GrossAmount*fxr.FXRate) * @DWTRate
							ELSE 0
					  END																						AS [DWT Deducted]
					, NULL																						AS [RWT deducted]
					, trn.ImputationCredit																		AS [Imputation credits]
					, NULL																						AS [Imputation credits & Foreign tax credits]
					, 0																							AS [Credit ratio]									/* TBC - Ben */
					, convert(bigint,round((1)*10000,0)) 														AS [AU exchange rate]
					, Qty																						AS [Shares]
					, Convert(Date,PayDate)																		AS [Payment Date]
					, Convert(Date,[Inception Date])															AS [Date Dividend Declared]							/* Confirm */
					, CASE
							WHEN	inc.Type	=	'Taxable Bonus' THEN	'T'
							ELSE											'F'
					  END																						AS [Bonus Issue] 
					, CASE
							WHEN inc.ShortDescription	=	'INT'	THEN (GrossAmount*fxr.FXRate)
							ELSE 0
					  END																						AS [Gross interest]
					, NULL																						AS [IPS deducted]
					, NULL																						AS [NRT deducted from interest]
					, NULL																						AS [NRT deducted from dividends]
					, NULL																						AS [NRT rate (interest)]
					, NULL																						AS [NRT rate (dividends)]
				 

				 --Other Attributes
  
						, crm.PrimaryContactFlag																AS [PrimaryContactFlag]
						, crm.IndividualAccountOrderFlag														AS [IndividualAccountOrderFlag]
						, fxr.FXRate																			AS [FXRate]
						, cur.Currency																			AS [CurrencyCode]
						, trn.Exchange																			AS [Exchange]
						, trn.SecCode																			AS [SecCode]
						, trn.AccID																				AS [tblTransactionAccID]
						, [PortfolioServiceStatus]	/*Remove for testing*/
						, ClosureDate				/*Remove for testing*/
						, tblTransactionID 
						, inc.Type																				AS	[IncomeType]
						, inc.ShortDescription																	AS	[IncomeTypeShortDescription]
						, inc.IsPie
						, inc.EligibleForResidentWithholdingTax 


				--Tax Attributes

						, trn.Tax1
						, trn.Tax1Amount
						, tax1map.ReportDescription																AS Tax1Description
						, trn.Tax2
						, trn.Tax2Amount
						, tax2map.ReportDescription																AS Tax2Description
						, trn.Tax3
						, trn.Tax3Amount
						, tax3map.ReportDescription																AS Tax3Description
										 
			   
		INTO	##FileDetail

		/*
		SELECT * FROM ##FileDetail
		WHERE
			Identifier  = '555608'
		*/

		

		FROM [SQLCIP].CSL.[dbo].[tblTransaction]																	trn

			LEFT JOIN #crmdatafatca_crs_final crm--#crmdatafatca 																	crm
				ON crm.[Portfolio No] COLLATE DATABASE_DEFAULT	=	trn.AccID	COLLATE DATABASE_DEFAULT
				--AND NOT
				--(crm.[Entity Type] = 'Joint' and crm.PrimaryContactFlag	=	2)


			JOIN [SQLCIP].CSL.dbo.tblIncType																		inc
				ON inc.IncTypeID		=	trn.IncType
				--and inc.IncTypeID		=	3

			LEFT JOIN [SQLCIP].CSL.[dbo].[tblCurrency]															cur
				ON cur.CID				=	trn.RecCurrency

			LEFT JOIN #FXRates																			fxr
				ON fxr.FXDate			=	trn.AsAtDate	
				AND fxr.CurrencyCode	=   cur.Currency

			LEFT JOIN #NoOfAccounts																		NoOfAcc
				ON NoOfAcc.AccID		=	trn.AccID

			LEFT JOIN [SQLCIP].CSL.Dbo.tblTaxDescription															tax1map
				ON tax1map.TaxID	= trn.Tax1

			LEFT JOIN [SQLCIP].CSL.Dbo.tblTaxDescription															tax2map
				ON tax2map.TaxID	= trn.Tax2

			LEFT JOIN [SQLCIP].CSL.Dbo.tblTaxDescription															tax3map
				ON tax3map.TaxID	= trn.Tax3

			LEFT JOIN [AACARPTSRV].fusion.dbo.Country													ISOctry
				ON ISOctry.name COLLATE DATABASE_DEFAULT = crm.[Country of Residence] COLLATE DATABASE_DEFAULT


--SELECT * FROM
--CSL.Dbo.tblTaxDescription

		WHERE
			ProcessDate								BETWEEN @ReturnPeriodBeg	and		@ReturnPeriodEnd
			
			--AND		trn.IssueAName <> 'Craigs Investment Partners Cash Management' /* Double check with BEN */
			AND SecCode NOT LIKE 'CCM%'


			--AND			
			--trn.AccID	IN	(SELECT splitdata	 FROM	DataServices.dbo.fnSplitString(@AccountsToTest,','))

			/* Remove - For testing */
			AND
			(
				(crm.[Entity Type] = 'Trust'					and	[Account Holder] = 'Individual' and  PrimaryContactFlag = 1)
				OR
				(crm.[Entity Type] = 'Individual'				and	[Account Holder] = 'Entity'     /*and  PrimaryContactFlag = 1*/) 
				--OR
				--(crm.[Entity Type] = 'Individual'				and (IndividualAccountOrderFlag = 1 and PrimaryContactFlag = 2))
				OR
				(crm.[Entity Type] = 'Company'					and	[Account Holder] = 'Entity')
				OR	
				(crm.[Entity Type] = 'Joint'					and	[Account Holder] IN ('Individual'/* ,'Entity' */) /* and PrimaryContactFlag = 1 */)
				OR
				(crm.[Entity Type] = 'Estate Winding-Up'		and	[Account Holder] = 'Entity')
				OR
				(crm.[Entity Type] = 'Incorporated Entity'		and	[Account Holder] = 'Entity')
				OR
				(crm.[Entity Type] = 'Minor Under 18 yrs'		and	[Account Holder] = 'Entity')
				OR
				(crm.[Entity Type] = 'Partnership'				and	[Account Holder] = 'Entity')
				OR
				(crm.[Entity Type] = 'Unincorporated Association'		and	[Account Holder] = 'Entity')
				OR
				(crm.[Entity Type] IS NULL)
			)






INSERT INTO CSL.dbo.tax_IRDReportingData
(
[IRDRunDate]			
, [IRDRunDateTime]		
, [IRDStatusFlag]		
, [IRDRunIteration]		

, [RoleFlag]												
, [Account Holder]											
, [Name]													
, [Individual Name]											
, [Recipient IRD number]									
, [Dividend recipient IRD number]							
, [Date of birth]											
, [Contact address]											
, [Country code]											
, [Email address]											
, [Phone number]											
, [Joint account or Joint investment]						
, [Number of account holders]								
, [RWT rate]												
, [Total Approved issuer Levy deducted]						
, [Total Gross Earnings]									
, [Total resident withholding tax deducted]					
, [Total non-resident withholding tax deducted]				
, [Identifier]												
, [Gross liable income]										
, [AIL deducted]											
, [Gross Dividend]											
, [Gross dividends treated as interest]						
, [DWT Deducted]											
, [RWT deducted]											
, [Imputation credits]										
, [Imputation credits & Foreign tax credits]				
, [Credit ratio]											
, [AU exchange rate]										
, [Shares]													
, [Payment Date]											
, [Date Dividend Declared]									
, [Bonus Issue]												
, [Gross interest]											
, [IPS deducted]											
, [NRT deducted from interest]								
, [NRT deducted from dividends]								
, [NRT rate (interest)]										
, [NRT rate (dividends)]									
, [PrimaryContactFlag]										
, [IndividualAccountOrderFlag]								
, [FXRate]													
, [CurrencyCode]											
, [Exchange]												
, [SecCode]													
, [tblTransactionAccID]										
, [PortfolioServiceStatus]									
, [ClosureDate]												
, [tblTransactionID]										
, [IncomeType]												
, [IncomeTypeShortDescription]								
, [IsPie]													
, [EligibleForResidentWithholdingTax]						
, [Tax1]													
, [Tax1Amount]												
, [Tax1Description]											
, [Tax2]													
, [Tax2Amount]												
, [Tax2Description]											
, [Tax3]													
, [Tax3Amount]												
, [Tax3Description]											
)

SELECT  
	--NULL												AS	[IRDPrimaryKey]			
	--,
	  convert(date,GetDate())							AS	[IRDRunDate]			
	, GetDate()											AS  [IRDRunDateTime]		
	, 1													AS	[IRDStatusFlag]		
	, 1													AS  [IRDRunIteration]		

, [RoleFlag]												
, [Account Holder]											
, [Name]													
, [Individual Name]											
, [Recipient IRD number]									
, [Dividend recipient IRD number]							
, [Date of birth]											
, [Contact address]											
, [Country code]											
, [Email address]											
, [Phone number]											
, [Joint account or Joint investment]						
, [Number of account holders]								
, [RWT rate]												
, [Total Approved issuer Levy deducted]						
, [Total Gross Earnings]									
, [Total resident withholding tax deducted]					
, [Total non-resident withholding tax deducted]				
, [Identifier]												
, [Gross liable income]										
, [AIL deducted]											
, [Gross Dividend]											
, [Gross dividends treated as interest]						
, [DWT Deducted]											
, [RWT deducted]											
, [Imputation credits]										
, [Imputation credits & Foreign tax credits]				
, [Credit ratio]											
, [AU exchange rate]										
, [Shares]													
, [Payment Date]											
, [Date Dividend Declared]									
, [Bonus Issue]												
, [Gross interest]											
, [IPS deducted]											
, [NRT deducted from interest]								
, [NRT deducted from dividends]								
, [NRT rate (interest)]										
, [NRT rate (dividends)]									
, [PrimaryContactFlag]										
, [IndividualAccountOrderFlag]								
, [FXRate]													
, [CurrencyCode]											
, [Exchange]												
, [SecCode]													
, [tblTransactionAccID]										
, [PortfolioServiceStatus]									
, [ClosureDate]												
, [tblTransactionID]										
, [IncomeType]												
, [IncomeTypeShortDescription]								
, [IsPie]													
, [EligibleForResidentWithholdingTax]						
, [Tax1]													
, [Tax1Amount]												
, [Tax1Description]											
, [Tax2]													
, [Tax2Amount]												
, [Tax2Description]											
, [Tax3]													
, [Tax3Amount]												
, [Tax3Description]						

FROM
##FileDetail



--END




 
/*

----RECON----
 
DECLARE @ReturnPeriodBeg Date			=   DATEADD(dd,1,DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-2,Getdate())))))
DECLARE @ReturnPeriodEnd Date			=	DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))) 


SELECT 
		Identifier 
		, sum(countoftransactiontest)	as countoftransactiontest
		, sum(countoftransactionrecon)	as countoftransactionrecon
		, sum(test) as test
		, sum(recon) as recon 
		, count(1) as overallcount

FROM

(
 

	SELECT 
		Identifier			COLLATE DATABASE_DEFAULT	as Identifier 
		, count(1)			as countoftransactiontest
		, 0					as countoftransactionrecon
		, 1 as test
		, 0 as recon
		--, NULL AS Name

		FROM ##FileDetail

	WHERE NOT (RoleFlag = 'Joint' and PrimaryContactFlag	=	2)

	group by Identifier 
	 
	

	UNION ALL  

	--DECLARE @ReturnPeriodEnd	Date			=	DATEADD(dd, -DAY(DATEADD(mm, 1, (DateAdd("M",-1,Getdate())))), DATEADD(mm, 1, (DateAdd("M",-1,Getdate()))))
	--DECLARE @ReturnPeriodBeg	Date			=	DATEADD(mm,-12,@ReturnPeriodEnd)

	SELECT 
		accID				COLLATE DATABASE_DEFAULT	as Identifier 
		,  0 											as countoftransactiontest
		,  count(1)										as countoftransactionrecon 
		,  0											as test
		,  1											as recon 

	FROM [SQLCIP].CSL.[dbo].[tblTransaction]			trn
	JOIN [SQLCIP].CSL.dbo.tblIncType																		inc
		ON inc.IncTypeID		=	trn.IncType
		--and inc.IncTypeID		=	3 

	WHERE
		ProcessDate	BETWEEN @ReturnPeriodBeg	and		@ReturnPeriodEnd
		AND SecCode NOT LIKE 'CCM%'


	GROUP BY  accID

) AS T
 
GROUP BY Identifier 

HAVING 
	sum(countoftransactiontest) <> sum(countoftransactionrecon)
	or 
	count(1) = 1
 
*/

--SELECT * FROM ##FileDetail
--ORDER BY 
--	Identifier
--	, Name
--	, [Payment Date]
--	, [Total Gross Earnings]


