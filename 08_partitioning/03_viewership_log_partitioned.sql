-- =============================================================================
-- FILE:    03_viewership_log_partitioned.sql
-- PURPOSE: Rebuild ops.viewership_log and audit.log to use partition schemes,
--          migrate existing data, and demonstrate partition elimination
-- DEPENDS: 02_partition_scheme.sql
-- NOTE:    In SQL Server you cannot ALTER an existing table to add partitioning.
--          You must: create new partitioned table → migrate data → rename.
--          This script does the full migration safely.
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- STEP 1: Create partitioned staging tables
-- These mirror the original schemas but use the partition scheme as their
-- ON clause for the clustered index.
-- =============================================================================

-- Partitioned viewership_log
IF OBJECT_ID('ops.viewership_log_partitioned', 'U') IS NOT NULL
    DROP TABLE ops.viewership_log_partitioned;

CREATE TABLE ops.viewership_log_partitioned (
    log_id               BIGINT          NOT NULL IDENTITY(1,1),
    rights_id            INT             NOT NULL,
    match_id             INT             NULL,
    peak_viewers         BIGINT          NOT NULL DEFAULT 0,
    avg_viewers          BIGINT          NOT NULL DEFAULT 0,
    stream_duration_min  SMALLINT        NULL,
    chat_messages        BIGINT          NULL,
    logged_at            DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_viewership_log_part
        PRIMARY KEY CLUSTERED (log_id, logged_at)
        ON ps_monthly_logs (logged_at),             -- partition key = logged_at

    CONSTRAINT FK_vlog_p_rights
        FOREIGN KEY (rights_id) REFERENCES ops.broadcast_rights(rights_id),
    CONSTRAINT FK_vlog_p_match
        FOREIGN KEY (match_id)  REFERENCES comp.match(match_id),
    CONSTRAINT CHK_vlog_p_viewers
        CHECK (peak_viewers >= 0 AND avg_viewers >= 0),
    CONSTRAINT CHK_vlog_p_peak
        CHECK (peak_viewers >= avg_viewers)
);
GO

-- Partitioned audit.log
IF OBJECT_ID('audit.log_partitioned', 'U') IS NOT NULL
    DROP TABLE audit.log_partitioned;

CREATE TABLE audit.log_partitioned (
    log_id        BIGINT          NOT NULL IDENTITY(1,1),
    schema_name   NVARCHAR(50)    NOT NULL,
    table_name    NVARCHAR(100)   NOT NULL,
    operation     NVARCHAR(10)    NOT NULL,
    record_id     INT             NULL,
    column_name   NVARCHAR(100)   NULL,
    old_value     NVARCHAR(MAX)   NULL,
    new_value     NVARCHAR(MAX)   NULL,
    changed_by    NVARCHAR(150)   NOT NULL DEFAULT SYSTEM_USER,
    app_context   NVARCHAR(100)   NULL,
    changed_at    DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_audit_log_part
        PRIMARY KEY CLUSTERED (log_id, changed_at)
        ON ps_monthly_logs (changed_at),            -- partition key = changed_at

    CONSTRAINT CHK_audit_p_operation
        CHECK (operation IN ('INSERT','UPDATE','DELETE','MERGE'))
);
GO

-- =============================================================================
-- STEP 2: Migrate existing data from original tables
-- =============================================================================

SET IDENTITY_INSERT ops.viewership_log_partitioned ON;

INSERT INTO ops.viewership_log_partitioned
    (log_id, rights_id, match_id, peak_viewers, avg_viewers,
     stream_duration_min, chat_messages, logged_at)
SELECT
    log_id, rights_id, match_id, peak_viewers, avg_viewers,
    stream_duration_min, chat_messages, logged_at
FROM ops.viewership_log;

SET IDENTITY_INSERT ops.viewership_log_partitioned OFF;
GO

SET IDENTITY_INSERT audit.log_partitioned ON;

INSERT INTO audit.log_partitioned
    (log_id, schema_name, table_name, operation, record_id,
     column_name, old_value, new_value, changed_by, app_context, changed_at)
SELECT
    log_id, schema_name, table_name, operation, record_id,
    column_name, old_value, new_value, changed_by, app_context, changed_at
FROM audit.log;

SET IDENTITY_INSERT audit.log_partitioned OFF;
GO

-- =============================================================================
-- STEP 3: Add non-clustered indexes on partitioned tables
--         Aligned indexes (using the same partition scheme) allow partition
--         elimination on secondary index seeks
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_vlog_p_match_id
    ON ops.viewership_log_partitioned (match_id)
    INCLUDE (rights_id, peak_viewers, avg_viewers, logged_at)
    ON ps_monthly_logs (logged_at);  -- aligned to partition scheme
GO

CREATE NONCLUSTERED INDEX IX_vlog_p_rights_id
    ON ops.viewership_log_partitioned (rights_id)
    INCLUDE (match_id, peak_viewers, avg_viewers, stream_duration_min, logged_at)
    ON ps_monthly_logs (logged_at);
GO

CREATE NONCLUSTERED INDEX IX_audit_p_table_op
    ON audit.log_partitioned (schema_name, table_name, operation)
    INCLUDE (record_id, changed_by, changed_at)
    ON ps_monthly_logs (changed_at);
GO

-- =============================================================================
-- STEP 4: Verify partitions received data
-- =============================================================================

SELECT
    p.partition_number,
    p.rows                                          AS row_count,
    CONVERT(NVARCHAR, prv_left.value, 120)          AS partition_from,
    CONVERT(NVARCHAR, prv_right.value, 120)         AS partition_to
FROM sys.partitions                 p
JOIN sys.indexes                    i
    ON i.object_id = p.object_id AND i.index_id = 1
JOIN sys.partition_schemes          ps
    ON ps.data_space_id = i.data_space_id
JOIN sys.partition_functions        pf
    ON pf.function_id = ps.function_id
LEFT JOIN sys.partition_range_values prv_left
    ON prv_left.function_id = pf.function_id
    AND prv_left.boundary_id = p.partition_number - 1
LEFT JOIN sys.partition_range_values prv_right
    ON prv_right.function_id = pf.function_id
    AND prv_right.boundary_id = p.partition_number
WHERE OBJECT_NAME(i.object_id) = 'viewership_log_partitioned'
  AND p.rows > 0
ORDER BY p.partition_number;
GO

-- =============================================================================
-- STEP 5: Demonstrate PARTITION ELIMINATION
--
-- The query optimiser skips partitions that can't contain qualifying rows.
-- You can verify this in the execution plan:
--   1. Run with CTRL+M (Include Actual Execution Plan) in SSMS
--   2. Hover over the Clustered Index Scan/Seek operator
--   3. "Actual Partition Count" should be 1 (only August 2025 scanned)
--      instead of 38 (all partitions)
-- =============================================================================

-- Query 1: August 2025 only — should touch 1 partition
SELECT
    vl.log_id,
    vl.rights_id,
    vl.peak_viewers,
    vl.avg_viewers,
    vl.logged_at,
    $PARTITION.pf_monthly_datetime2(vl.logged_at)   AS partition_number
FROM ops.viewership_log_partitioned vl
WHERE vl.logged_at >= '2025-08-01'
  AND vl.logged_at <  '2025-09-01';
GO

-- Query 2: Q3 2025 (Jul–Sep) — should touch 3 partitions
SELECT
    vl.match_id,
    vl.peak_viewers,
    vl.avg_viewers,
    vl.logged_at,
    $PARTITION.pf_monthly_datetime2(vl.logged_at)   AS partition_number
FROM ops.viewership_log_partitioned vl
WHERE vl.logged_at >= '2025-07-01'
  AND vl.logged_at <  '2025-10-01'
ORDER BY vl.logged_at;
GO

-- Query 3: Cross-partition aggregation — total viewers per month
SELECT
    YEAR(vl.logged_at)                              AS yr,
    MONTH(vl.logged_at)                             AS mo,
    $PARTITION.pf_monthly_datetime2(vl.logged_at)   AS partition_num,
    COUNT(*)                                        AS log_entries,
    SUM(vl.peak_viewers)                            AS total_peak,
    AVG(vl.avg_viewers)                             AS avg_concurrent
FROM ops.viewership_log_partitioned vl
GROUP BY
    YEAR(vl.logged_at),
    MONTH(vl.logged_at),
    $PARTITION.pf_monthly_datetime2(vl.logged_at)
ORDER BY yr, mo;
GO

-- =============================================================================
-- STEP 6: Swap in as the production table (rename pattern)
-- Run this when you're satisfied the partitioned copy is correct.
--
-- sp_rename 'ops.viewership_log',             'viewership_log_old';
-- sp_rename 'ops.viewership_log_partitioned', 'viewership_log';
-- sp_rename 'audit.log',                      'log_old';
-- sp_rename 'audit.log_partitioned',          'log';
-- DROP TABLE ops.viewership_log_old;
-- DROP TABLE audit.log_old;
-- =============================================================================

PRINT '03_viewership_log_partitioned.sql: partitioned tables created and data migrated.';
GO
