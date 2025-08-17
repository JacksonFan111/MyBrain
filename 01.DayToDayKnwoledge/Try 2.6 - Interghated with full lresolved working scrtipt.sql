/* =======================================================================
   CRM AUDIT MASTER: OLD vs CURRENT for MULTIPLE FIELDS (single-pass)
   -----------------------------------------------------------------------
   PURPOSE (what this script outputs)
   ---------------------------------
   For each target field you specify as a pair (OTC, ColumnNumber):
     • Finds recent audit rows where that specific field changed.
     • Decodes the Audit payload to extract the OLD value for that field.
     • If the field is an OptionSet, translates numeric value → label.
     • If the field is a Lookup, translates GUID → referenced row’s name.
     • Reads the CURRENT value from the live record and translates similarly.
     • Resolves a friendly TargetRecordName (e.g., “Contoso Ltd <Active>”).
     • Appends one human-friendly row per change to #AuditRollup.

   IMPORTANT CONCEPTS
   ------------------
   • OTC (ObjectTypeCode): numeric code for an entity (e.g., 1=Account, 2=Contact).
   • ColumnNumber: the per-entity numeric ID for a field (from Metadata).
   • Audit.AttributeMask: comma list of ColumnNumbers changed in one save.
   • Audit.ChangeData: “~”-separated list of pieces, each "AttrName,OldValue".
     ▸ AttributeMask and ChangeData are parallel lists; we align them by position.
   • OptionSet label lookup: StringMap(ObjectTypeCode, AttributeName, AttributeValue).
   • Lookup translation: resolve GUIDs to names using referenced entity’s “name-ish” column.

   SAFETY
   ------
   • Read-only; no writes.
   • Collation-safe joins/strings via DATABASE_DEFAULT when relevant.
   • Dynamic SQL used only to inject table/column identifiers safely.

   HOW TO USE
   ----------
   1) Adjust @Days lookback and @Targets below.
   2) Run; read the final SELECT from #AuditRollup.

   ======================================================================= */

USE CRM_MSCRM;
SET NOCOUNT ON;  -- avoid rowcount chatter in the output

/* ===================== 0) WINDOW SETTINGS ===================== */
DECLARE @Days  int      = 30;                                  -- look-back window in days
DECLARE @Since datetime = DATEADD(DAY, -@Days, GETUTCDATE()); -- compute UTC cutoff

PRINT 'Audit window (UTC) since: ' + CONVERT(varchar(19), @Since, 120);

/* ===================== 1) TARGETS TO AUDIT ====================
   Add (OTC, ColumnNumber) pairs.

   ▸ How to find ColumnNumbers:
     Join MetadataSchema.Attribute → MetadataSchema.Entity, filter by
     Entity.ObjectTypeCode and Attribute.Name, then read Attribute.ColumnNumber.
   ============================================================= */
DECLARE @Targets TABLE(OTC int NOT NULL, ColNum int NOT NULL);

INSERT INTO @Targets(OTC, ColNum)
VALUES
---- Audit the Accoutn tables Chanegs
 -- (1, 22),       -- Account → Entity Name -- Ususally no Changes
-- (1, 10136)   -- Account → dsl_primaryadviserid (Lookup)
  --(1, 10122),    -- Account → dsl_advisercommissioncodeid (Lookup)
  --(1, 10179),    -- Account → dsl_portfoliosearchingids (Text/CSV-ish)
 
	
	--(1, 10169),    -- Account → Holdings Updated On
	--(1, 10170)   -- Account → Total Holdings Value
	--(1, 10293),    -- Account → FI/NFFE
	--(1, 10303),    -- Account → Passive or Active
    -- (1, 10309),    -- Account → US Citizen/s for Tax Purposes
	--(1, 10376),    -- Account → Charity No.
	--(1, 10507)   -- Account → Foreign Tax Resident

---- Audit the Contacts tables Chanegs
 -- (2, 10069),   -- Contact → dsl_primaryadviserid (Lookup)
 -- (2, 26) ,     -- Contact → fullname (NOTE: some orgs use 26; verify in metadata)
 -- (2, 30),       -- Contact → Birthday
 -- (2, 42)  ,      -- Contact →  Emails 
 -- (2, 10311) ,      -- Contact	dsl_mobilephone	10311
	--(2, 10028),    -- Contact → NZ Resident Status
	--(2, 10129),    -- Contact → Compliance Passed
	(2, 10167),    -- Contact → US Citizen/s for Tax Purposes
	(2, 10254)   -- Contact → Town/City of Birth
	--(2, 10266),    -- Contact → Self Certification

	-- Audit the Portfolio Service changes
	--(10042, 33),   -- Portfolio Service → Name
	--(10042, 36),   -- Portfolio Service → Inception Date
	--(10042, 40),  -- Portfolio Service → Portfolio Service Status
	--(10042, 49)  -- Portfolio Service → Adviser Commission Code (Lookup: 10003)
	--(10042, 55),   -- Portfolio Service → Nominee (Lookup: 10034)
	--(10042, 65),   -- Portfolio Service → Day of Month
	--(10042, 72),   -- Portfolio Service → Plus Months
	--(10042, 81),   -- Portfolio Service → Next 4 Bill Date
	--(10042, 82),   -- Portfolio Service → Next Bill Date
	--(10042, 113),  -- Portfolio Service → Effective From
	--(10042, 115),  -- Portfolio Service → Reason for Suitability
	--(10042, 121),  -- Portfolio Service → Reason for Closure (Lookup: 10014)
	--(10042, 125),  -- Portfolio Service → Strategic Asset Allocation (Lookup: 10249)
	--(10042, 136),  -- Portfolio Service → Total Holdings Value (Base)
	--(10042, 225),  -- Portfolio Service → CS Review Completed Date
	--(10042, 226),  -- Portfolio Service → Has Review in Progress
	--(10042, 229),  -- Portfolio Service → IPS Generated
	--(10042, 231),  -- Portfolio Service → IPS Generated Date
	--(10042, 232),  -- Portfolio Service → IPS Scanned Date
	--(10042, 233),  -- Portfolio Service → IPS Signed
	--(10042, 235),  -- Portfolio Service → IPS Signed Date
	--(10042, 236),  -- Portfolio Service → Next CS Review Date
	--(10042, 237),  -- Portfolio Service → Next Portfolio Review Date
	--(10042, 238),  -- Portfolio Service → Portfolio Review Completed Date
	--(10042, 245),  -- Portfolio Service → NS Scanned Date
	--(10042, 246),  -- Portfolio Service → NS Signed
	--(10042, 248)   -- Portfolio Service → NS Signed Date


-- Audit the roels chanegs 
	--(10051, 3),    -- Roles → Created By
	--(10051, 5),    -- Roles → Modified By
	--(10051, 21),   -- Roles → Owning Business Unit
	--(10051, 22),   -- Roles → Owning User
	--(10051, 23),   -- Roles → Owning Team
	--(10051, 50),   -- Roles → Entity
	--(10051, 53),   -- Roles → Parent Entity
	--(10051, 56),   -- Roles → Individual
	--(10051, 59),   -- Roles → Primary Role
	--(10051, 65)   -- Roles → Secondary Role


/* ===================== 2) OUTPUT TABLES ======================= */

-- MAIN ROLLUP: one row per audited change you care about
IF OBJECT_ID('tempdb..#AuditRollup') IS NOT NULL DROP TABLE #AuditRollup;
CREATE TABLE #AuditRollup(
  OTC                int,                  -- entity OTC
  EntityLogicalName  sysname NULL,         -- e.g., 'account'
  EntityDisplayName  nvarchar(400) NULL,   -- e.g., 'Account'
  ColNum             int,                  -- ColumnNumber of the field
  FieldLogicalName   sysname,              -- e.g., 'name'
  FieldDisplayName   nvarchar(400) NULL,   -- e.g., 'Account Name'
  ChangeTimeLocal    datetime,             -- audit CreatedOn converted to local time
  ChangedBy          nvarchar(256),        -- user display name from Audit
  AuditId            uniqueidentifier,     -- Audit row Id
  ActionLabel        nvarchar(400) NULL,   -- e.g., 'Update', 'Create', 'Delete'
  ObjectId           uniqueidentifier,     -- the changed record's PK GUID
  TargetRecordName   nvarchar(500) NULL,   -- resolved friendly name of the record
  OldRaw             nvarchar(max) NULL,   -- raw old value from ChangeData
  OldOptionLabel     nvarchar(max) NULL,   -- OptionSet label if applicable
  OldGuid            uniqueidentifier NULL,-- lookup Guid if applicable
  OldLookupName      nvarchar(max) NULL,   -- lookup friendly name if applicable
  CurrentRaw         nvarchar(max) NULL,   -- current raw value from live row
  CurrentOptionLabel nvarchar(max) NULL,   -- current OptionSet label if applicable
  CurrentLookupName  nvarchar(max) NULL,   -- current lookup friendly name if applicable
  OldResolved        nvarchar(max) NULL,   -- best human-readable OLD (label/name/raw)
  CurrentResolved    nvarchar(max) NULL,   -- best human-readable CURRENT (label/name/raw)
  IsDifferent        bit                   -- comparison flag (OldResolved vs CurrentResolved)
);

-- CACHE FOR RECORD NAMES: ensures we compute TargetRecordName once per (OTC,ObjectId)
IF OBJECT_ID('tempdb..#ObjNames') IS NOT NULL DROP TABLE #ObjNames;
CREATE TABLE #ObjNames(
  OTC        int              NOT NULL,    -- entity OTC
  ObjectId   uniqueidentifier NOT NULL,    -- record Id
  ObjectName nvarchar(500)    NULL,        -- friendly name, e.g., 'Contoso Ltd <Active>'
  CONSTRAINT PK_ObjNames PRIMARY KEY (OTC, ObjectId)
);

/* ===================== 3) MAIN CURSOR OVER TARGETS ============ */
DECLARE curTargets CURSOR LOCAL FAST_FORWARD FOR
  SELECT t.OTC, t.ColNum
  FROM @Targets t;

DECLARE @OTC int, @ColNum int;
OPEN curTargets;
FETCH NEXT FROM curTargets INTO @OTC, @ColNum;

WHILE @@FETCH_STATUS = 0
BEGIN
  PRINT '--- Auditing OTC=' + CAST(@OTC AS varchar(10)) + ' ColumnNumber=' + CAST(@ColNum AS varchar(10)) + ' ---';

  /* --- 3.1 Resolve the entity (table/view/PK + names) --- */
  DECLARE @Base sysname = NULL,   -- base storage table name
          @Phys sysname = NULL,   -- physical/readable object (often same as filtered view)
          @PK   sysname = NULL;   -- primary key column name
  DECLARE @EntityLogical sysname = NULL,       -- logical entity name (schema name)
          @EntityDisplay nvarchar(400) = NULL; -- localized display label

  -- read entity plumbing (base table, physical name, logical name)
  SELECT
    @Base          = ev.BaseTableName,
    @Phys          = ev.PhysicalName,
    @EntityLogical = ev.Name
  FROM dbo.EntityView ev
  WHERE ev.ObjectTypeCode = @OTC;

  -- read friendly display label (EN) for the entity
  SELECT @EntityDisplay = llv.Label
  FROM dbo.EntityView ev
  JOIN dbo.LocalizedLabelView llv
    ON llv.ObjectId = ev.EntityId
   AND llv.ObjectColumnName='LocalizedName'
   AND llv.LanguageId=1033
  WHERE ev.ObjectTypeCode = @OTC;

  -- guard: ensure entity resolved
  IF @Base IS NULL
  BEGIN
    PRINT 'Skip: Unknown OTC ' + CAST(@OTC AS varchar(10));
    GOTO NextTarget;
  END

  -- find the base table's PK column name via dictionary
  SELECT TOP 1 @PK = kcu.COLUMN_NAME
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
  WHERE kcu.TABLE_SCHEMA='dbo'
    AND kcu.TABLE_NAME=@Base
    AND OBJECTPROPERTY(OBJECT_ID(kcu.CONSTRAINT_SCHEMA+'.'+kcu.CONSTRAINT_NAME),'IsPrimaryKey')=1;

  IF @PK IS NULL
  BEGIN
    PRINT 'Skip: Could not resolve PK for OTC ' + CAST(@OTC AS varchar(10));
    GOTO NextTarget;
  END

  /* --- 3.2 Resolve the attribute by (OTC, ColumnNumber) --- */
  DECLARE @AttrName  sysname = NULL,        -- field logical name
          @IsOptionSet bit = 0,             -- true if OptionSet
          @RefOTC     int  = NULL,          -- referenced entity OTC if lookup
          @FieldLabel nvarchar(400) = NULL; -- field display label

  ;WITH A AS (
    SELECT a.AttributeId, a.Name, a.ColumnNumber, a.OptionSetId,
           a.ReferencedEntityObjectTypeCode, e.EntityId
    FROM MetadataSchema.Attribute a
    JOIN MetadataSchema.Entity    e ON e.EntityId=a.EntityId
    WHERE e.ObjectTypeCode=@OTC AND a.ColumnNumber=@ColNum
  )
  SELECT TOP 1
    @AttrName    = A.Name,
    @IsOptionSet = CASE WHEN A.OptionSetId IS NULL THEN 0 ELSE 1 END,
    @RefOTC      = A.ReferencedEntityObjectTypeCode,
    @FieldLabel  = llv.Label
  FROM A
  LEFT JOIN dbo.LocalizedLabelView llv
    ON llv.ObjectId = A.AttributeId
   AND llv.ObjectColumnName='DisplayName'
   AND llv.LanguageId=1033;

  IF @AttrName IS NULL
  BEGIN
    PRINT 'Skip: ColumnNumber ' + CAST(@ColNum AS varchar(10)) + ' not found on OTC ' + CAST(@OTC AS varchar(10));
    GOTO NextTarget;
  END

  /* --- 3.3 Pull audit rows for this (OTC, ColNum) within time window --- */
  IF OBJECT_ID('tempdb..#E') IS NOT NULL DROP TABLE #E;
  SELECT
    a.AuditId,                                    -- unique audit id
    a.ObjectId,                                   -- the changed record id
    a.CreatedOn,                                  -- UTC timestamp
    a.UserIdName,                                 -- who made the change
    sm.Value AS ActionLabel,                      -- 'Create'/'Update'/'Delete'
    LTRIM(RTRIM(a.AttributeMask)) AS AttributeMask,          -- comma list of ColumnNumbers
    REPLACE(a.ChangeData, CHAR(39), '') AS ChangeData        -- raw "~" payload, strip single-quotes
  INTO #E
  FROM dbo.Audit a
  LEFT JOIN dbo.StringMap sm
         ON sm.AttributeName='Action' AND sm.AttributeValue=a.Action
  WHERE a.ObjectTypeCode=@OTC                 -- same entity
    AND a.CreatedOn>=@Since                   -- within window
    AND a.AttributeMask NOT LIKE '%[A-Za-z]%' -- numeric masks only
    AND a.AttributeMask LIKE '%,'+CAST(@ColNum AS varchar)+',%'  -- mentions our ColumnNumber
    AND NULLIF(a.ChangeData,'') IS NOT NULL;  -- has a payload

  -- if no audit rows for this target, skip quietly
  IF NOT EXISTS(SELECT 1 FROM #E)
  BEGIN
    PRINT 'Info: No audit rows for OTC ' + CAST(@OTC AS varchar(10)) + ' ColNum ' + CAST(@ColNum AS varchar(10)) + ' in last ' + CAST(@Days AS varchar(10)) + ' day(s).';
    GOTO NextTarget;
  END



  /* --- 3.4 Split AttributeMask (CSV) & ChangeData ("~"); align by position --- */
  
  -- Split the comma list mask into a JSON array, keep 1-based ordinal "pos"
  IF OBJECT_ID('tempdb..#Mask') IS NOT NULL DROP TABLE #Mask;
  SELECT
    e.AuditId, e.ObjectId, e.CreatedOn, e.UserIdName,
    j.[key]+1 AS pos,                          -- 1-based index
    TRY_CONVERT(int,j.value) AS ColNum         -- ColumnNumber at that position
  INTO #Mask
  FROM #E e
  CROSS APPLY OPENJSON(
    '["' + REPLACE(
             CASE WHEN LEN(e.AttributeMask)>3
                  THEN SUBSTRING(e.AttributeMask,2,LEN(e.AttributeMask)-2)  -- trim leading/trailing commas
                  ELSE e.AttributeMask END,
             ',', '","') + '"]'
  ) j
  WHERE TRY_CONVERT(int,j.value) IS NOT NULL;


	  -- Split ChangeData by "~" ONLY; keep whole chunk; normalize pos (0 → 1)
	IF OBJECT_ID('tempdb..#Vals') IS NOT NULL DROP TABLE #Vals;

	;WITH Chunks AS (
	  SELECT
		  e.AuditId,
		  e.ObjectId,
		  e.CreatedOn,
		  s.[key] AS k,  -- 0-based
		  LTRIM(RTRIM(CONVERT(nvarchar(max), s.value))) AS chunk
	  FROM #E e
	  CROSS APPLY (SELECT j = N'["' + REPLACE(STRING_ESCAPE(e.ChangeData,'json'), '~', '","') + N'"]') jj
	  CROSS APPLY OPENJSON(jj.j) AS s
	  WHERE  s.value IS NOT NULL
	)
	SELECT
		AuditId,
		ObjectId,
		CreatedOn,
		CASE WHEN k = 0 THEN 1 ELSE k + 1 END AS pos,  -- shift to 1-based, guard single-chunk case
		chunk AS OldValueRaw               -- no comma-splitting here
	INTO #Vals
	FROM Chunks
	;



-- Align by ordinal and keep only the 1 field we care about (our ColumnNumber)
IF OBJECT_ID('tempdb..#Changes') IS NOT NULL DROP TABLE #Changes;

SELECT
    m.AuditId,
    m.ObjectId,
    m.CreatedOn,
    m.UserIdName,

    -- full payload chunk (never split for free text)
    v.OldValueRaw,

    -- derived: last comma position (NULL if no comma or OldValueRaw is NULL)
    last_comma = CASE 
                   WHEN v.OldValueRaw IS NOT NULL AND CHARINDEX(',', v.OldValueRaw) > 0
                     THEN LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1
                 END,

    -- derived: left/right tokens around the *last* comma (for lookups/options)
    LeftToken  = CASE 
                   WHEN v.OldValueRaw IS NOT NULL AND CHARINDEX(',', v.OldValueRaw) > 0 AND
                        (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) > 1
                     THEN LEFT(v.OldValueRaw, (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) - 1)
                 END,
    RightToken = CASE 
                   WHEN v.OldValueRaw IS NOT NULL AND CHARINDEX(',', v.OldValueRaw) > 0
                     THEN SUBSTRING(
                            v.OldValueRaw,
                            (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) + 1,
                            4000
                          )
                   ELSE v.OldValueRaw
                 END,

    -- helper: does the left token look like an entity/logical name? (no spaces/punct)
    LeftLooksLikeEntity = CASE 
                            WHEN v.OldValueRaw IS NOT NULL AND CHARINDEX(',', v.OldValueRaw) > 0
                                 AND PATINDEX('%[^a-zA-Z0-9_]%', 
                                              LEFT(v.OldValueRaw, (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) - 1)
                                             ) = 0
                              THEN 1 ELSE 0 END,

    -- parsed GUID (safe):
    --  - if "word_like,GUID" and GUID valid → use RightToken
    --  - else if whole value is a GUID → use OldValueRaw
    --  - else NULL
    OldGuid = CASE 
                WHEN v.OldValueRaw IS NOT NULL
                     AND CHARINDEX(',', v.OldValueRaw) > 0
                     AND PATINDEX('%[^a-zA-Z0-9_]%', 
                                  LEFT(v.OldValueRaw, (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) - 1)
                                 ) = 0
                     AND TRY_CONVERT(uniqueidentifier,
                                     SUBSTRING(
                                       v.OldValueRaw,
                                       (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) + 1,
                                       4000)) IS NOT NULL
                  THEN TRY_CONVERT(uniqueidentifier,
                                   SUBSTRING(
                                     v.OldValueRaw,
                                     (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) + 1,
                                     4000))
                WHEN TRY_CONVERT(uniqueidentifier, v.OldValueRaw) IS NOT NULL
                  THEN TRY_CONVERT(uniqueidentifier, v.OldValueRaw)
                ELSE NULL
              END,

    -- optional: numeric old value (useful for OptionSets). Same safety rule as GUID.
    OldNumber = CASE
                  WHEN TRY_CONVERT(int, v.OldValueRaw) IS NOT NULL
                    THEN TRY_CONVERT(int, v.OldValueRaw)
                  WHEN v.OldValueRaw IS NOT NULL
                       AND CHARINDEX(',', v.OldValueRaw) > 0
                       AND PATINDEX('%[^a-zA-Z0-9_]%', 
                                    LEFT(v.OldValueRaw, (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) - 1)
                                   ) = 0
                       AND TRY_CONVERT(int,
                           SUBSTRING(
                             v.OldValueRaw,
                             (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) + 1,
                             4000)
                         ) IS NOT NULL
                    THEN TRY_CONVERT(int,
                           SUBSTRING(
                             v.OldValueRaw,
                             (LEN(v.OldValueRaw) - CHARINDEX(',', REVERSE(v.OldValueRaw)) + 1) + 1,
                             4000))
                  ELSE NULL
                END
INTO #Changes
FROM #Mask m
JOIN #Vals v
  ON v.AuditId   = m.AuditId
 AND v.ObjectId  = m.ObjectId
 AND v.CreatedOn = m.CreatedOn
 AND v.pos       = m.pos
WHERE m.ColNum = @ColNum;

  /* --- 3.5 OptionSet label maps (old/current) for this field if applicable --- */
  IF OBJECT_ID('tempdb..#OptOld') IS NOT NULL DROP TABLE #OptOld;
  SELECT DISTINCT sm.AttributeValue, sm.Value
  INTO #OptOld
  FROM StringMap sm
  WHERE @IsOptionSet=1
    AND sm.ObjectTypeCode=@OTC
    AND sm.AttributeName=@AttrName;

  IF OBJECT_ID('tempdb..#OptCur') IS NOT NULL DROP TABLE #OptCur;
  SELECT DISTINCT sm.AttributeValue, sm.Value
  INTO #OptCur
  FROM StringMap sm
  WHERE @IsOptionSet=1
    AND sm.ObjectTypeCode=@OTC
    AND sm.AttributeName=@AttrName;

  /* --- 3.6 Current values (live row now) for edited records --- */
  IF OBJECT_ID('tempdb..#Current') IS NOT NULL DROP TABLE #Current;
  CREATE TABLE #Current(ObjectId uniqueidentifier, CurrentRaw nvarchar(max));

  -- Build a set-based query to fetch CURRENT values for all touched records
  DECLARE @sqlCur nvarchar(max) = N'
    INSERT #Current(ObjectId, CurrentRaw)
    SELECT a.'+QUOTENAME(@PK)+N', CAST(a.'+QUOTENAME(@AttrName)+N' AS nvarchar(max))
    FROM dbo.'+QUOTENAME(@Base)+N' a
    JOIN (SELECT DISTINCT ObjectId FROM #Changes) d
      ON d.ObjectId=a.'+QUOTENAME(@PK)+N';';
  EXEC (@sqlCur);

  /* --- 3.6b Resolve TargetRecordName (integrated; cached in #ObjNames) --- */

  -- Heuristically pick a "name-ish" column for this entity
  DECLARE @NameCol sysname=NULL;
  SELECT TOP 1 @NameCol = a.Name
  FROM MetadataSchema.Attribute a
  JOIN MetadataSchema.Entity me ON me.EntityId=a.EntityId
  WHERE me.ObjectTypeCode=@OTC
    AND (
      LOWER(a.Name) IN ('name','fullname','subject','title','dsl_name','cip_name')
      OR (a.AttributeLogicalTypeId='text' AND a.Name LIKE '%name')
    )
  ORDER BY CASE
            WHEN LOWER(a.Name) IN ('name','fullname') THEN 1
            WHEN LOWER(a.Name) IN ('subject','title','dsl_name','cip_name') THEN 2
            WHEN a.Name LIKE '%name' THEN 3
            ELSE 9
          END;

  -- Fallbacks by OTC (entity) if metadata didn’t yield a name column
  IF @NameCol IS NULL
  BEGIN
    SET @NameCol = CASE @OTC
      WHEN 1 THEN N'name'        -- Account
      WHEN 2 THEN N'fullname'    -- Contact
      WHEN 8 THEN N'fullname'    -- SystemUser
      WHEN 4212 THEN N'subject'  -- Task
      WHEN 10003 THEN N'dsl_name'
      WHEN 10010 THEN N'dsl_name'
      WHEN 10042 THEN N'dsl_name'
      WHEN 10051 THEN N'dsl_name'
      WHEN 10071 THEN N'dsl_name'
      WHEN 10288 THEN N'dsl_name'
      ELSE N'name'
    END;
  END

  -- If the physical table has statecode, we’ll append <StateLabel> (e.g., <Active>)
  DECLARE @hasState bit = CASE WHEN EXISTS (
    SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.'+@Phys) AND name='statecode'
  ) THEN 1 ELSE 0 END;

  -- Insert friendly names for all ObjectIds in this OTC (no duplicates thanks to NOT EXISTS)
  DECLARE @sqlName nvarchar(max) =
    N'INSERT INTO #ObjNames(OTC,ObjectId,ObjectName)
      SELECT '+CAST(@OTC AS varchar(10))+N', t.'+QUOTENAME(@PK)+N',
             '+
             CASE WHEN @hasState=1
               THEN N'CASE WHEN sm.Value IS NOT NULL
                           THEN CAST(t.'+QUOTENAME(@NameCol)+N' AS nvarchar(500)) + N'' <''+sm.Value+N''>''
                           ELSE CAST(t.'+QUOTENAME(@NameCol)+N' AS nvarchar(500)) END'
               ELSE N'CAST(t.'+QUOTENAME(@NameCol)+N' AS nvarchar(500))'
             END
      +N'
      FROM dbo.'+QUOTENAME(@Phys)+N' t
      JOIN (SELECT DISTINCT ObjectId FROM #Changes) d
        ON d.ObjectId = t.'+QUOTENAME(@PK)+N'
      '+
      CASE WHEN @hasState=1
           THEN N'LEFT JOIN dbo.StringMap sm
                    ON sm.ObjectTypeCode='+CAST(@OTC AS varchar(10))+N'
                   AND sm.AttributeName=''statecode''
                   AND sm.AttributeValue = t.statecode'
           ELSE N''
      END + N'
      WHERE NOT EXISTS(
        SELECT 1 FROM #ObjNames x
        WHERE x.OTC='+CAST(@OTC AS varchar(10))+N'
          AND x.ObjectId=t.'+QUOTENAME(@PK)+N');';

  EXEC sp_executesql @sqlName;

  /* --- 3.7 Lookup names for OLD & CURRENT (only if field is a lookup) --- */

  IF OBJECT_ID('tempdb..#RefNamesOld') IS NOT NULL DROP TABLE #RefNamesOld;
  IF OBJECT_ID('tempdb..#RefNamesCur') IS NOT NULL DROP TABLE #RefNamesCur;
  CREATE TABLE #RefNamesOld(Id uniqueidentifier, RefName nvarchar(max)); -- OLD guid -> name
  CREATE TABLE #RefNamesCur(Id uniqueidentifier, RefName nvarchar(max)); -- CUR guid -> name

  IF @RefOTC IS NOT NULL
  BEGIN
    DECLARE @RefBase sysname, @RefPhys sysname, @RefPK sysname, @RefNameCol sysname;

    -- Find the referenced entity’s objects
    SELECT @RefBase = ev.BaseTableName, @RefPhys = ev.PhysicalName
    FROM dbo.EntityView ev
    WHERE ev.ObjectTypeCode=@RefOTC;

    -- PK of referenced base table
    SELECT TOP 1 @RefPK = kcu.COLUMN_NAME
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    WHERE kcu.TABLE_SCHEMA='dbo' AND kcu.TABLE_NAME=@RefBase
      AND OBJECTPROPERTY(OBJECT_ID(kcu.CONSTRAINT_SCHEMA+'.'+kcu.CONSTRAINT_NAME),'IsPrimaryKey')=1;

    -- Choose a friendly name column on the referenced entity (prefer 'name','fullname', then common variants)
    SELECT TOP 1 @RefNameCol=a2.Name
    FROM MetadataSchema.Attribute a2
    JOIN MetadataSchema.Entity e2 ON e2.EntityId=a2.EntityId
    WHERE e2.ObjectTypeCode=@RefOTC
      AND a2.Name IN ('name','fullname','dsl_Name','cip_name','subject','title')
    ORDER BY CASE WHEN a2.Name IN ('name','fullname') THEN 1 ELSE 2 END;

    IF @RefNameCol IS NULL SET @RefNameCol=@RefPK;  -- fallback: use PK if needed

    /* OLD GUIDs parsed from c.OldValueRaw
       Note: the payload might be "logicalname,guid" or just "guid". We normalize it. */
    IF OBJECT_ID('tempdb..#OldIds') IS NOT NULL DROP TABLE #OldIds;
    SELECT DISTINCT TRY_CONVERT(uniqueidentifier,
             CASE WHEN CHARINDEX(',',c.OldValueRaw)>0
                  THEN PARSENAME(REPLACE(c.OldValueRaw,',','.'),1) -- take the part after comma
                  ELSE c.OldValueRaw END) AS Id
    INTO #OldIds
    FROM #Changes c
    WHERE c.OldValueRaw IS NOT NULL;

    -- Fetch friendly names for OLD ids
    DECLARE @sqlOld nvarchar(max) = N'
      INSERT #RefNamesOld(Id, RefName)
      SELECT t.'+QUOTENAME(@RefPK)+N', CAST(t.'+QUOTENAME(@RefNameCol)+N' AS nvarchar(max))
      FROM dbo.'+QUOTENAME(@RefPhys)+N' t
      JOIN #OldIds d ON d.Id = t.'+QUOTENAME(@RefPK)+N';';
    EXEC (@sqlOld);

    /* CURRENT GUIDs coming from live row */
    IF OBJECT_ID('tempdb..#CurIds') IS NOT NULL DROP TABLE #CurIds;
    SELECT DISTINCT TRY_CONVERT(uniqueidentifier, cu.CurrentRaw) AS Id
    INTO #CurIds
    FROM #Current cu
    WHERE TRY_CONVERT(uniqueidentifier, cu.CurrentRaw) IS NOT NULL;

    -- Fetch friendly names for CURRENT ids
    DECLARE @sqlCurRef nvarchar(max) = N'
      INSERT #RefNamesCur(Id, RefName)
      SELECT t.'+QUOTENAME(@RefPK)+N', CAST(t.'+QUOTENAME(@RefNameCol)+N' AS nvarchar(max))
      FROM dbo.'+QUOTENAME(@RefPhys)+N' t
      JOIN #CurIds d ON d.Id = t.'+QUOTENAME(@RefPK)+N';';
    EXEC (@sqlCurRef);
  END

  /* --- 3.8 Append final row(s) to #AuditRollup (with TargetRecordName) --- */

  INSERT INTO #AuditRollup(
    OTC, EntityLogicalName, EntityDisplayName,
    ColNum, FieldLogicalName, FieldDisplayName,
    ChangeTimeLocal, ChangedBy, AuditId, ActionLabel, ObjectId, TargetRecordName,
    OldRaw, OldOptionLabel, OldGuid, OldLookupName,
    CurrentRaw, CurrentOptionLabel, CurrentLookupName,
    OldResolved, CurrentResolved, IsDifferent
  )
  SELECT
    @OTC,                         -- entity OTC
    @EntityLogical,               -- logical name (e.g., 'account')
    @EntityDisplay,               -- display label (e.g., 'Account')
    @ColNum,                      -- ColumnNumber of field
    @AttrName,                    -- field logical name
    @FieldLabel,                  -- field display name
    dbo.fn_UTCToLocalTime_rpt(c.CreatedOn) AS ChangeTimeLocal,  -- convert UTC->local
    c.UserIdName                            AS ChangedBy,       -- who changed it
    e.AuditId,                              
    e.ActionLabel,                           -- 'Update'/'Create'/...
    c.ObjectId,                              -- changed record Id
    onm.ObjectName,                          -- resolved friendly record name

    /* OLD side */
    c.OldValueRaw AS OldRaw,                 -- raw old value
    CASE WHEN @IsOptionSet=1 AND ISNUMERIC(c.OldValueRaw)=1
         THEN o.Value END COLLATE DATABASE_DEFAULT AS OldOptionLabel, -- OptionSet label (if any)
    CASE WHEN @RefOTC IS NOT NULL
         THEN TRY_CONVERT(uniqueidentifier,
              CASE WHEN CHARINDEX(',',c.OldValueRaw)>0
                   THEN PARSENAME(REPLACE(c.OldValueRaw,',','.'),1)
                   ELSE c.OldValueRaw END) END                           AS OldGuid, -- GUID if lookup
    ro.RefName COLLATE DATABASE_DEFAULT                                   AS OldLookupName, -- friendly lookup name

    /* CURRENT side */
    cu.CurrentRaw                                                         AS CurrentRaw, -- raw current value
    CASE WHEN @IsOptionSet=1 AND ISNUMERIC(cu.CurrentRaw)=1
         THEN oc.Value END COLLATE DATABASE_DEFAULT                       AS CurrentOptionLabel, -- OptionSet label
    rc.RefName COLLATE DATABASE_DEFAULT                                   AS CurrentLookupName,  -- friendly lookup name

    /* RESOLVED comparisons (what a human sees) */
    COALESCE(o.Value,  ro.RefName,  c.OldValueRaw)  COLLATE DATABASE_DEFAULT AS OldResolved,
    COALESCE(oc.Value, rc.RefName,  cu.CurrentRaw)  COLLATE DATABASE_DEFAULT AS CurrentResolved,

    /* Change flag: differ if normalized strings differ */
    CASE
      WHEN ISNULL(COALESCE(o.Value,  ro.RefName,  c.OldValueRaw),'') COLLATE DATABASE_DEFAULT
         = ISNULL(COALESCE(oc.Value, rc.RefName,  cu.CurrentRaw),'') COLLATE DATABASE_DEFAULT
      THEN 0 ELSE 1
    END AS IsDifferent
  FROM #Changes c
  JOIN #E e               ON e.AuditId = c.AuditId
  LEFT JOIN #Current cu   ON cu.ObjectId = c.ObjectId
  LEFT JOIN #OptOld  o    ON @IsOptionSet=1 AND ISNUMERIC(c.OldValueRaw)=1
                         AND TRY_CONVERT(int,c.OldValueRaw)=o.AttributeValue
  LEFT JOIN #OptCur  oc   ON @IsOptionSet=1 AND ISNUMERIC(cu.CurrentRaw)=1
                         AND TRY_CONVERT(int,cu.CurrentRaw)=oc.AttributeValue
  LEFT JOIN #RefNamesOld ro ON @RefOTC IS NOT NULL
                            AND ro.Id = TRY_CONVERT(uniqueidentifier,
                                       CASE WHEN CHARINDEX(',',c.OldValueRaw)>0
                                            THEN PARSENAME(REPLACE(c.OldValueRaw,',','.'),1)
                                            ELSE c.OldValueRaw END)
  LEFT JOIN #RefNamesCur rc ON @RefOTC IS NOT NULL
                            AND rc.Id = TRY_CONVERT(uniqueidentifier, cu.CurrentRaw)
  LEFT JOIN #ObjNames onm   ON onm.OTC = @OTC AND onm.ObjectId = c.ObjectId;

  --/* --- 3.9 Clean temp objects for this target (defensive) --- */
  IF OBJECT_ID('tempdb..#E')            IS NOT NULL DROP TABLE #E;
  IF OBJECT_ID('tempdb..#Mask')         IS NOT NULL DROP TABLE #Mask;
  IF OBJECT_ID('tempdb..#Vals')         IS NOT NULL DROP TABLE #Vals;
  IF OBJECT_ID('tempdb..#Changes')      IS NOT NULL DROP TABLE #Changes;
  IF OBJECT_ID('tempdb..#OptOld')       IS NOT NULL DROP TABLE #OptOld;
  IF OBJECT_ID('tempdb..#OptCur')       IS NOT NULL DROP TABLE #OptCur;
  IF OBJECT_ID('tempdb..#Current')      IS NOT NULL DROP TABLE #Current;
  IF OBJECT_ID('tempdb..#RefNamesOld')  IS NOT NULL DROP TABLE #RefNamesOld;
  IF OBJECT_ID('tempdb..#RefNamesCur')  IS NOT NULL DROP TABLE #RefNamesCur;
  IF OBJECT_ID('tempdb..#OldIds')       IS NOT NULL DROP TABLE #OldIds;
  IF OBJECT_ID('tempdb..#CurIds')       IS NOT NULL DROP TABLE #CurIds;


--Select Top 100 * from
--  #E
--  WHERE AuditId = 'A1F9DC86-D877-F011-A869-000D3ACA9042'

----  #Mask
---- AuditId	ObjectId	CreatedOn	UserIdName	pos	ColNum
----D020A5FD-865B-F011-A867-000D3ACA9042	BF56C1A2-2F3C-F011-A312-6045BDE50BBB	2025-07-07 23:06:26.890	Craig Wallace	1	40

--Select Top 100 * from
--#Vals
--WHERE AuditId = 'D020A5FD-865B-F011-A867-000D3ACA9042'

NextTarget:
  FETCH NEXT FROM curTargets INTO @OTC, @ColNum;
END

CLOSE curTargets;
DEALLOCATE curTargets;

/* ===================== 4) FINAL RESULTS =======================
   Show only rows where the resolved OLD != CURRENT value.
   Ordered by entity/field/time for readability.
   ============================================================= */
SELECT *
FROM #AuditRollup
WHERE 1=1
--IsDifferent = 1
--AND OldRaw IS NOT NULL
ORDER BY OTC, FieldDisplayName, ChangeTimeLocal DESC;

/* ===================== QUICK REFERENCE / TIPS ==================
   • To add another field: append (OTC, ColumnNumber) to @Targets.
   • To find ColumnNumber: query MetadataSchema.Attribute/Entity by logical name.
   • If TargetRecordName is null for an entity, add a fallback in the @NameCol CASE.
   • If Contact fullname appears under a different ColumnNumber (common: 26), update @Targets.
   • If you want a longer window, increase @Days.

   METADATA CHEAT (discover ColumnNumbers & “name-ish” columns)
   ------------------------------------------------------------
   -- Example: list candidate “name” columns for an entity OTC=1
   SELECT a.Name, a.ColumnNumber, a.AttributeLogicalTypeId
   FROM MetadataSchema.Attribute a
   JOIN MetadataSchema.Entity e ON e.EntityId=a.EntityId
   WHERE e.ObjectTypeCode=1
     AND (LOWER(a.Name) IN ('name','fullname','subject','title','dsl_name','cip_name')
          OR (a.AttributeLogicalTypeId='text' AND a.Name LIKE '%name'))
   ORDER BY a.Name;
   ============================================================= */

