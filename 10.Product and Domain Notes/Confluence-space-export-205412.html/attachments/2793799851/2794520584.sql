WITH RankedAssets AS (
    SELECT  
        ISNULL(a.SecurityCode, '') + '.' + ISNULL(m.Code, '') AS Sec_Exc,
        ROW_NUMBER() OVER (
            PARTITION BY a.SecurityCode, m.Code 
            ORDER BY a.ShortName ASC
        ) AS RowNum,
        
        a.AssetID,
        a.ShortName,
        a.MarketID,
        a.IssuerName,
        a.AssetSectorID,
        a.SecurityCode,
        a.SecurityTypeID,
        
        CASE 
            WHEN m.Code = 'NZX' THEN 'NZSE' 
            WHEN LOWER(m.Description) LIKE '%temporary%' THEN 'Unlisted'
            ELSE m.Code 
        END AS Exchange,
        
        ass.Code AS AssetSectorCode,
        ass.Description AS AssetSectorDescription,
        m.Description AS MarketDescription
      
    FROM 
        [svsqlcrm\sqlcrm].[AACPR].[dbo].Asset a
    INNER JOIN 
        [svsqlcrm\sqlcrm].[AACPR].[dbo].AssetSector ass 
        ON ass.AssetSectorID = a.AssetSectorID
    INNER JOIN 
        [svsqlcrm\sqlcrm].[AACPR].[dbo].Market m 
        ON m.MarketID = a.MarketID
),

MismatchedAssets AS (
    SELECT 
        ra.Sec_Exc,
        ra.AssetID,
        ra.SecurityCode,
        ra.Exchange,
        ra.ShortName,
        ra.MarketID,
        ra.IssuerName,
        ra.AssetSectorID,
        ra.SecurityTypeID,
        ra.AssetSectorCode,
        ra.AssetSectorDescription,
        ra.RowNum,
        ra.MarketDescription,
        COUNT(*) OVER (PARTITION BY ra.Sec_Exc) AS DuplicateCount
    FROM 
        RankedAssets ra
    WHERE 
        ra.Exchange <> 'NUL'
        --AND ra.AssetSectorCode IN ('AE','IE')
        --AND ra.Exchange = 'ASX'
		AND ra.SecurityCode = 'CCP'
)

SELECT 
    ma.Sec_Exc,
    ma.AssetID,
    ma.SecurityCode,
    ma.Exchange,
    ma.ShortName,
    ma.MarketID,
    ma.IssuerName,
    ma.AssetSectorID,
    ma.SecurityTypeID,
    ma.AssetSectorCode,
    ma.AssetSectorDescription,
    ma.RowNum,
    ma.DuplicateCount,
    ma.MarketDescription
FROM 
    MismatchedAssets ma
WHERE 
    ma.DuplicateCount > 1
    --AND ma.RowNum > 1
ORDER BY 
    ma.AssetID,
    ma.Sec_Exc,
    ma.RowNum;
