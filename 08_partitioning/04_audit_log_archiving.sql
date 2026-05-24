-- =============================================================================
-- FILE:    04_audit_log_archiving.sql
-- PURPOSE: Implement the sliding window partition pattern for audit.log
--          — add new monthly partition, archive oldest month via SWITCH,
--            drop or move to cold storage
-- DEPENDS: 03_viewership_log_partitioned.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- THE SLIDING WINDOW PATTERN
--
-- For append-heavy tables like audit.log you want to:
--   1. Regularly ADD a new empty partition for the upcoming month (SPLIT)
--   2. SWITCH OUT the oldest partition to an archive table (instant metadata op)
--   3. Either DROP the archive table or backup and truncate it
--
-- SWITCH is near-instantaneous — it moves a partition by changing metadata only.
-- No data movement occurs. This is why partition archiving beats DELETE for
-- large tables.
--
-- Prerequisites for SWITCH:
--   - Source and target must have identical schema (columns, types, constraints)
--   - Target table must be empty
--   - Target must be on the SAME filegroup as the source partition
--   - No foreign keys can reference the source table
--   - Indexes must be aligned (same partition scheme or non-partitioned on same FG)
-- =============================================================================

-- =============================================================================
-- STEP 1: Create the archive staging table
-- Must match audit.log_partitioned exactly — same columns, no partition
-- Sits on FG_LOGS (same as the partition being switched out)
-- =============================================================================

IF OBJECT_ID('audit.log_archive_staging', 'U') IS NOT NULL
    DROP TABLE audit.log_archive_staging;

CREATE TABLE audit.log_archive_staging (
    log_id        BIGINT          NOT NULL,
    schema_name   NVARCHAR(50)    NOT NULL,
    table_name    NVARCHAR(100)   NOT NULL,
    operation     NVARCHAR(10)    NOT NULL,
    record_id     INT             NULL,
    column_name   NVARCHAR(100)   NULL,
    old_value     NVARCHAR(MAX)   NULL,
    new_value     NVARCHAR(MAX)   NULL,
    changed_by    NVARCHAR(150)   NOT NULL,
    app_context   NVARCHAR(100)   NULL,
    changed_at    DATETIME2(0)    NOT NULL,

    -- Must match the clustered index structure of the partitioned source
    CONSTRAINT PK_audit_archive PRIMARY KEY CLUSTERED (log_id, changed_at)
) ON FG_LOGS;   -- same filegroup as the FG_LOGS partition being switched out
GO

-- =============================================================================
-- STEP 2: Utility view — which partitions have data and how old are they?
-- Run this to decide which partition to archive next
-- =============================================================================

CREATE OR ALTER VIEW audit.vw_partition_inventory
AS
SELECT
    p.partition_number,
    p.rows                                          AS row_count,
    CONVERT(NVARCHAR(20), prv_left.value, 120)      AS partition_from,
    CONVERT(NVARCHAR(20), prv_right.value, 120)     AS partition_to,
    CASE
        WHEN prv_right.value < GETUTCDATE()
        THEN 'Archivable'
        ELSE 'Active'
    END                                             AS partition_status,
    fg.name                                         AS filegroup_name
FROM sys.partitions                 p
JOIN sys.indexes                    i
    ON  i.object_id = p.object_id
    AND i.index_id  = 1
JOIN sys.partition_schemes          ps
    ON  ps.data_space_id = i.data_space_id
JOIN sys.partition_functions        pf
    ON  pf.function_id = ps.function_id
JOIN sys.destination_data_spaces    dds
    ON  dds.partition_scheme_id = ps.data_space_id
    AND dds.destination_id      = p.partition_number
JOIN sys.data_spaces                fg
    ON  fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values prv_left
    ON  prv_left.function_id  = pf.function_id
    AND prv_left.boundary_id  = p.partition_number - 1
LEFT JOIN sys.partition_range_values prv_right
    ON  prv_right.function_id = pf.function_id
    AND prv_right.boundary_id = p.partition_number
WHERE OBJECT_NAME(i.object_id) = 'log_partitioned'
  AND OBJECT_SCHEMA_NAME(i.object_id) = 'audit';
GO

-- =============================================================================
-- STEP 3: Sliding window procedure
-- Encapsulates the full monthly cycle:
--   a) Extend partition scheme for the new month
--   b) Split the RIGHT boundary to create the new empty partition
--   c) Switch the oldest non-empty partition to the archive staging table
--   d) Log the operation
-- =============================================================================

CREATE OR ALTER PROCEDURE audit.usp_slide_partition_window
    @archive_month    DATE,          -- first day of month to archive, e.g. '2025-01-01'
    @new_month        DATE,          -- first day of new month to add,  e.g. '2026-02-01'
    @result_msg       NVARCHAR(300) = NULL OUTPUT,
    @success          BIT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @success    = 0;
    SET @result_msg = '';

    DECLARE
        @archive_partition  INT,
        @archive_row_count  BIGINT,
        @next_month_start   DATE = DATEADD(MONTH, 1, @new_month);

    -- -------------------------------------------------------------------------
    -- Validate: archive month must be in the past
    -- -------------------------------------------------------------------------
    IF @archive_month >= CAST(GETUTCDATE() AS DATE)
    BEGIN
        SET @result_msg = 'ERROR: Cannot archive a current or future month.';
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- Find which partition number contains the archive month
    -- -------------------------------------------------------------------------
    SET @archive_partition = $PARTITION.pf_monthly_datetime2(
        CAST(@archive_month AS DATETIME2)
    );

    SELECT @archive_row_count = rows
    FROM sys.partitions p
    JOIN sys.indexes    i ON i.object_id = p.object_id AND i.index_id = 1
    WHERE OBJECT_NAME(i.object_id) = 'log_partitioned'
      AND OBJECT_SCHEMA_NAME(i.object_id) = 'audit'
      AND p.partition_number = @archive_partition;

    IF @archive_row_count IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: Partition ', @archive_partition, ' not found.');
        RETURN;
    END

    BEGIN TRY

        -- -------------------------------------------------------------------------
        -- a) Extend the partition scheme to accommodate the new month
        -- -------------------------------------------------------------------------
        ALTER PARTITION SCHEME ps_monthly_logs
            NEXT USED FG_LOGS;

        -- -------------------------------------------------------------------------
        -- b) Add the new month boundary (SPLIT creates a new empty partition)
        -- -------------------------------------------------------------------------
        ALTER PARTITION FUNCTION pf_monthly_datetime2()
            SPLIT RANGE (CAST(@next_month_start AS DATETIME2));

        -- -------------------------------------------------------------------------
        -- c) Ensure archive staging table is empty, then SWITCH
        -- -------------------------------------------------------------------------
        TRUNCATE TABLE audit.log_archive_staging;

        ALTER TABLE audit.log_partitioned
            SWITCH PARTITION @archive_partition
            TO audit.log_archive_staging;

        -- -------------------------------------------------------------------------
        -- d) At this point audit.log_archive_staging holds the old month's data.
        --    In production you would:
        --      - Backup the staging table to cold storage / data lake
        --      - INSERT into a permanent archive table with a DATETIME2 partition
        --      - Or just TRUNCATE after verifying backup
        -- For this script we log the operation and leave the data in staging.
        -- -------------------------------------------------------------------------
        INSERT INTO audit.log
            (schema_name, table_name, operation, record_id, new_value, changed_by, app_context)
        VALUES
            ('audit', 'log_partitioned', 'MERGE', NULL,
             CONCAT('Archived partition ', @archive_partition,
                    ' (', @archive_month, ') — ', @archive_row_count, ' rows. ',
                    'New partition added for ', @new_month, '.'),
             SYSTEM_USER, 'usp_slide_partition_window');

        SET @success    = 1;
        SET @result_msg = CONCAT(
            'SUCCESS: Partition ', @archive_partition,
            ' (', FORMAT(@archive_month, 'MMM yyyy'), ') archived — ',
            FORMAT(@archive_row_count, 'N0'), ' rows switched to staging. ',
            'New partition added for ', FORMAT(@next_month_start, 'MMM yyyy'), '.'
        );

    END TRY
    BEGIN CATCH
        SET @result_msg = CONCAT('ERROR: ', ERROR_MESSAGE());
    END CATCH
END;
GO

-- =============================================================================
-- STEP 4: MERGE — removing a boundary (opposite of SPLIT)
-- Used when you want to consolidate two low-volume partitions
-- e.g. merge two near-empty months into one partition
--
-- NOTE: Always verify both partitions are small before MERGE.
--       MERGE on large partitions causes data movement and log growth.
--
-- ALTER PARTITION FUNCTION pf_monthly_datetime2()
--     MERGE RANGE ('2024-02-01');  -- removes the Feb 2024 boundary
--                                  -- Jan and Feb data now in same partition
-- =============================================================================

-- =============================================================================
-- STEP 5: Monitoring queries for partition health
-- =============================================================================

-- Partition fill rate — how full is each active partition?
SELECT
    pv.partition_number,
    pv.partition_from,
    pv.partition_to,
    pv.row_count,
    pv.partition_status,
    -- Estimated size in MB (rough: 500 bytes avg row for audit log)
    ROUND(pv.row_count * 500.0 / 1024 / 1024, 2)   AS est_size_mb
FROM audit.vw_partition_inventory pv
ORDER BY pv.partition_number;
GO

-- Pages per partition (more accurate sizing)
SELECT
    p.partition_number,
    SUM(a.total_pages)                              AS total_pages,
    SUM(a.used_pages)                               AS used_pages,
    ROUND(SUM(a.total_pages) * 8.0 / 1024, 2)      AS total_mb,
    ROUND(SUM(a.used_pages)  * 8.0 / 1024, 2)      AS used_mb
FROM sys.partitions             p
JOIN sys.allocation_units       a ON a.container_id = p.hobt_id
JOIN sys.indexes                i ON i.object_id    = p.object_id
                                 AND i.index_id     = p.index_id
WHERE OBJECT_NAME(i.object_id)        = 'log_partitioned'
  AND OBJECT_SCHEMA_NAME(i.object_id) = 'audit'
  AND i.index_id = 1
GROUP BY p.partition_number
ORDER BY p.partition_number;
GO

-- =============================================================================
-- Usage example (run manually after data has been live for 2+ months):
-- DECLARE @msg NVARCHAR(300), @ok BIT;
-- EXEC audit.usp_slide_partition_window
--     @archive_month = '2025-01-01',
--     @new_month     = '2026-02-01',
--     @result_msg    = @msg OUTPUT,
--     @success       = @ok  OUTPUT;
-- SELECT @ok AS success, @msg AS message;
-- =============================================================================

PRINT '04_audit_log_archiving.sql: archive staging table, inventory view, and sliding window procedure created.';
GO
