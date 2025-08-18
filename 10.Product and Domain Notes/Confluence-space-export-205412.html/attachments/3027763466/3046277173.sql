-------------------------------------------------------------------------------
-- 0) Parameterize Job Names if needed (or hard-code them if always the same)
-------------------------------------------------------------------------------
DECLARE @Job1Name VARCHAR(100) = 'TMS5_Napier_DailyDataLoad';
DECLARE @Job2Name VARCHAR(100) = 'TMS5_Napier_DailyDataLoadTrans';

-------------------------------------------------------------------------------
-- 1) Pull from multiple batches at once:
--    For example, 1282 and 1285. Adjust as needed.
-------------------------------------------------------------------------------
WITH TargetBatches AS (
    SELECT 1282 AS BatchID
    UNION ALL
    SELECT 1285
),

-------------------------------------------------------------------------------
-- 2) Define the Job Hierarchy for both jobs
-------------------------------------------------------------------------------
JobHierarchy AS (
    -- Job1 steps (1.1–2.9)
    SELECT 'Data Loading' AS TableName, 'Started' AS TableStatus, @Job1Name AS AgentJobName, '1.1' AS JobStep, 'Initialize data refresh.' AS TaskDescription
    UNION ALL SELECT 'Data Loading', 'Started', @Job1Name, '1.2', '[dbo].[usp_PopulateSourceData] - Starts data refresh.'
    UNION ALL SELECT 'TempTables Loading', 'Started', @Job1Name, '1.3', '[dbo].[usp_Populating_TempTables] - Loads temp tables.'
    UNION ALL SELECT 'Temp Table_Account', 'Started', @Job1Name, '1.4', 'Loads Temp Table_Account.'
    UNION ALL SELECT 'Temp Table_Account', 'Completed', @Job1Name, '1.5', 'Completes Temp Table_Account.'
    UNION ALL SELECT 'Temp Table_Contact', 'Started', @Job1Name, '1.6', 'Loads Temp Table_Contact.'
    UNION ALL SELECT 'Temp Table_Contact', 'Completed', @Job1Name, '1.7', 'Completes Temp Table_Contact.'
    UNION ALL SELECT 'Temp Table_Temp Balance', 'Started', @Job1Name, '1.8', 'Loads Temp Table_Temp Balance.'
    UNION ALL SELECT 'Temp Table_Temp Balance', 'Completed', @Job1Name, '1.9', 'Completes Temp Table_Temp Balance.'
    UNION ALL SELECT 'Temp Table_Wrapport Trns', 'Started', @Job1Name, '1.10', 'Loads Temp Table_Wrapport Trns.'
    UNION ALL SELECT 'Temp Table_Wrapport Trns', 'Completed', @Job1Name, '1.11', 'Completes Temp Table_Wrapport Trns.'
    UNION ALL SELECT 'Temp Table_Start', 'Started', @Job1Name, '1.12', 'Loads Temp Table_Start.'
    UNION ALL SELECT 'Temp Table_Start', 'Completed', @Job1Name, '1.13', 'Completes Temp Table_Start.'
    UNION ALL SELECT 'TempTables Loading', 'Completed', @Job1Name, '1.14', 'Ends temp tables loading.'
    UNION ALL SELECT 'Accounts', 'Started', @Job1Name, '1.15', 'Loads dbo.Accounts.'
    UNION ALL SELECT 'Accounts', 'Completed', @Job1Name, '1.16', 'Completes dbo.Accounts.'
    UNION ALL SELECT 'LegalEntities', 'Started', @Job1Name, '1.17', 'Loads dbo.LegalEntities.'
    UNION ALL SELECT 'LegalEntities', 'Completed', @Job1Name, '1.18', 'Completes dbo.LegalEntities.'
    UNION ALL SELECT 'Persons', 'Started', @Job1Name, '1.19', 'Loads dbo.Persons.'
    UNION ALL SELECT 'Persons', 'Completed', @Job1Name, '1.20', 'Completes dbo.Persons.'
    UNION ALL SELECT 'Roles', 'Started', @Job1Name, '1.21', 'Loads dbo.Roles.'
    UNION ALL SELECT 'Roles', 'Completed', @Job1Name, '1.22', 'Completes dbo.Roles.'
    UNION ALL SELECT 'Staging_Transactions', 'Started', @Job1Name, '1.23', '[dbo].[usp_Populating_Staging_Transactions] - Refreshes staging transactions.'
    UNION ALL SELECT 'Staging_Transactions', 'Completed', @Job1Name, '1.24', 'Completes staging transactions.'
    UNION ALL SELECT 'Transactions', 'Started', @Job1Name, '1.25', '[dbo].[usp_Populating_Transactions] - Refreshes main Transactions.'
    UNION ALL SELECT 'Transactions', 'Completed', @Job1Name, '1.26', 'Completes Transactions.'
    UNION ALL SELECT 'Data Loading', 'Completed', @Job1Name, '1.27', 'Ends data loading.'
    UNION ALL SELECT 'Roles - Exporting to CSV', 'Started', @Job1Name, '2.1', 'C#-ExportCSVEngine - Exports Roles.'
    UNION ALL SELECT 'Roles - Exporting to CSV', 'Completed', @Job1Name, '2.2', 'C#-ExportCSVEngine - Completes Roles.'
    UNION ALL SELECT 'Persons - Exporting to CSV', 'Started', @Job1Name, '2.3', 'C#-ExportCSVEngine - Exports Persons.'
    UNION ALL SELECT 'Persons - Exporting to CSV', 'Completed', @Job1Name, '2.4', 'C#-ExportCSVEngine - Completes Persons.'
    UNION ALL SELECT 'LegalEntities - Exporting to CSV', 'Started', @Job1Name, '2.5', 'C#-ExportCSVEngine - Exports LegalEntities.'
    UNION ALL SELECT 'LegalEntities - Exporting to CSV', 'Completed', @Job1Name, '2.6', 'C#-ExportCSVEngine - Completes LegalEntities.'
    UNION ALL SELECT 'Accounts - Exporting to CSV', 'Started', @Job1Name, '2.7', 'C#-ExportCSVEngine - Exports Accounts.'
    UNION ALL SELECT 'Accounts - Exporting to CSV', 'Completed', @Job1Name, '2.8', 'C#-ExportCSVEngine - Completes Accounts.'
    UNION ALL SELECT 'CSV Generating and Uploading', 'Completed Successfully', @Job1Name, '2.9', '[dbo].[usp_sp_send_dbmail_Success] - Sends success email.'

    -- Job2 steps (3.1–3.4)
    UNION ALL SELECT 'Transactions - Exporting to CSV', 'Started', @Job2Name, '3.1', 'C#-ExportCSVEngine - Starts Transactions CSV.'
    UNION ALL SELECT 'temp_trans', 'Started', @Job2Name, '3.2', '[dbo].[usp_vwTransactionsExport] - Creates temp_trans.'
    UNION ALL SELECT 'temp_trans', 'Completed', @Job2Name, '3.2', '[dbo].[usp_vwTransactionsExport] - Completes temp_trans.'
    UNION ALL SELECT 'Transactions - Exporting to CSV', 'Completed', @Job2Name, '3.3', 'C#-ExportCSVEngine - Completes Transactions CSV.'
    UNION ALL SELECT 'CSV Generating and Uploading', 'Completed Successfully', @Job2Name, '3.4', '[dbo].[usp_sp_send_dbmail_Success_Trans] - Sends success email.'
),

-------------------------------------------------------------------------------
-- 3) Find each batch's boundary between Job1 and Job2
-------------------------------------------------------------------------------
TimeMarker AS (
    SELECT
        b.BatchID,
        -- earliest "Transactions - Exporting to CSV / Started" for that batch
        MIN(
            CASE WHEN b.TableName = 'Transactions - Exporting to CSV'
                 AND b.TableStatus = 'Started'
            THEN b.CreatedDate END
        ) AS Job2StartTime
    FROM [SQLCIP].[TMS5_Napier].[ETL].[BatchLog] b
    INNER JOIN TargetBatches tb ON b.BatchID = tb.BatchID
    GROUP BY b.BatchID
),

-------------------------------------------------------------------------------
-- 4) EnhancedLog: fix known bad rows & determine job name
-------------------------------------------------------------------------------
EnhancedLog AS (
    SELECT 
        b.ID,
        b.BatchID,
        b.BatchStatus,
        b.TableName,

        /* 
           CASE to override known bad rows:
           - (1282, 50712) was actually 'Completed'
           - (1285, 50832) was actually 'Completed'
           Add more rows if needed:
        */
        CASE 
          WHEN (b.BatchID = 1282 AND b.ID = 50712) THEN 'Completed'
          WHEN (b.BatchID = 1285 AND b.ID = 50832) THEN 'Completed'
          ELSE b.TableStatus
        END AS EffectiveTableStatus,

        b.CurrentRowsCount,
        b.CreatedDate,
        b.ErrorMessage,

        -- Which job name does this row belong to?
        CASE 
          WHEN b.CreatedDate < tm.Job2StartTime THEN @Job1Name
          ELSE @Job2Name
        END AS AgentJobName,

        jh.JobStep,
        jh.TaskDescription,

        ROW_NUMBER() OVER (
            PARTITION BY 
                b.BatchID,
                b.TableName,
                /* partition by the "corrected" TableStatus */
                CASE 
                  WHEN (b.BatchID = 1282 AND b.ID = 50712) THEN 'Completed'
                  WHEN (b.BatchID = 1285 AND b.ID = 50832) THEN 'Completed'
                  ELSE b.TableStatus
                END,
                /* also partition by the correct job name */
                CASE 
                  WHEN b.CreatedDate < tm.Job2StartTime THEN @Job1Name
                  ELSE @Job2Name
                END
            ORDER BY b.CreatedDate, b.ID
        ) AS RowNum
    FROM [SQLCIP].[TMS5_Napier].[ETL].[BatchLog] b
    INNER JOIN TargetBatches tb ON b.BatchID = tb.BatchID
    LEFT JOIN TimeMarker tm ON b.BatchID = tm.BatchID
    LEFT JOIN JobHierarchy jh
        ON  b.TableName = jh.TableName
        AND CASE 
              WHEN (b.BatchID = 1282 AND b.ID = 50712) THEN 'Completed'
              WHEN (b.BatchID = 1285 AND b.ID = 50832) THEN 'Completed'
              ELSE b.TableStatus
            END = jh.TableStatus
        AND jh.AgentJobName = CASE 
                               WHEN b.CreatedDate < tm.Job2StartTime THEN @Job1Name
                               ELSE @Job2Name
                             END
),

-------------------------------------------------------------------------------
-- 5) FinalOutput: pick the single row per step, show corrected statuses
-------------------------------------------------------------------------------
FinalOutput AS (
    SELECT 
        b.ID,
        b.BatchID,
        b.BatchStatus,
        b.TableName,

        el.EffectiveTableStatus AS TableStatus,

        b.CurrentRowsCount,
        b.CreatedDate,
        b.ErrorMessage,
        el.AgentJobName,
        el.JobStep,
        el.TaskDescription,

        COUNT(*) OVER (PARTITION BY b.BatchID) AS TotalStepsPerBatch
    FROM [SQLCIP].[TMS5_Napier].[ETL].[BatchLog] b
    INNER JOIN EnhancedLog el 
        ON b.ID = el.ID 
       AND b.BatchID = el.BatchID
    WHERE el.RowNum = 1
)

-------------------------------------------------------------------------------
-- 6) Return results for all selected batches
-------------------------------------------------------------------------------
SELECT 
    ID,
    BatchID,
    BatchStatus,
    TableName,
    TableStatus,
    CurrentRowsCount,
    CreatedDate,
    ErrorMessage,
    AgentJobName,
    JobStep,
    TaskDescription,
    TotalStepsPerBatch
FROM FinalOutput
ORDER BY
    -- First by BatchID so each batch's steps group together
    BatchID,
    -- Then numeric sort of the JobStep (1.9 < 1.10 < 2.1 < 3.2, etc.)
    CAST(PARSENAME(JobStep, 2) AS INT),
    CAST(PARSENAME(JobStep, 1) AS INT),
    ID;
