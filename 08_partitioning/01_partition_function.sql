-- =============================================================================
-- FILE:    01_partition_function.sql
-- PURPOSE: Define partition functions for date-based table partitioning
--          Used by viewership_log and audit.log (both on FG_LOGS)
-- DEPENDS: 01_schema/01_create_database.sql (FG_LOGS filegroup must exist)
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- PARTITION FUNCTION CONCEPTS
--
-- A partition function defines HOW rows are distributed across partitions.
-- It maps a column value (the partition key) to a partition number.
--
-- RANGE LEFT  → boundary value belongs to the LEFT  (lower) partition
-- RANGE RIGHT → boundary value belongs to the RIGHT (higher) partition
--
-- Example with RANGE RIGHT on monthly dates:
--   Boundary: '2025-02-01'
--   Row with date '2025-01-31' → partition 1 (before boundary)
--   Row with date '2025-02-01' → partition 2 (on boundary → goes RIGHT = higher)
--   Row with date '2025-03-15' → partition 3
--
-- RANGE RIGHT is standard for date partitioning:
--   "everything in January" sits in partition 1
--   "everything in February" sits in partition 2
--   The boundary IS the start of the next partition
-- =============================================================================

-- =============================================================================
-- pf_monthly_datetime2
-- Monthly partitioning on DATETIME2(0) columns.
-- Used by: ops.viewership_log (logged_at), audit.log (changed_at)
-- Covers 2024 through 2026 — add new boundaries annually via ALTER PARTITION FUNCTION
-- =============================================================================

-- Drop if exists (for re-runs)
IF EXISTS (
    SELECT 1 FROM sys.partition_functions
    WHERE name = 'pf_monthly_datetime2'
)
BEGIN
    -- Must drop scheme first, then function
    IF EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'ps_monthly_logs')
        DROP PARTITION SCHEME ps_monthly_logs;
    DROP PARTITION FUNCTION pf_monthly_datetime2;
    PRINT 'Dropped existing pf_monthly_datetime2 and ps_monthly_logs.';
END
GO

CREATE PARTITION FUNCTION pf_monthly_datetime2 (DATETIME2(0))
AS RANGE RIGHT FOR VALUES (
    -- 2024 boundaries
    '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01',
    '2024-05-01', '2024-06-01', '2024-07-01', '2024-08-01',
    '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
    -- 2025 boundaries
    '2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
    '2025-05-01', '2025-06-01', '2025-07-01', '2025-08-01',
    '2025-09-01', '2025-10-01', '2025-11-01', '2025-12-01',
    -- 2026 boundaries
    '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01',
    '2026-05-01', '2026-06-01', '2026-07-01', '2026-08-01',
    '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01'
);
GO

-- =============================================================================
-- pf_quarterly_date
-- Quarterly partitioning on DATE columns.
-- Used by: ops.ticket_order (ordered_at cast to date)
-- Useful when monthly granularity is too fine for smaller tables
-- =============================================================================

IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'pf_quarterly_date')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'ps_quarterly_ops')
        DROP PARTITION SCHEME ps_quarterly_ops;
    DROP PARTITION FUNCTION pf_quarterly_date;
END
GO

CREATE PARTITION FUNCTION pf_quarterly_date (DATE)
AS RANGE RIGHT FOR VALUES (
    '2024-01-01', '2024-04-01', '2024-07-01', '2024-10-01',
    '2025-01-01', '2025-04-01', '2025-07-01', '2025-10-01',
    '2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01'
);
GO

-- =============================================================================
-- Verify partition functions created
-- =============================================================================

SELECT
    pf.name                                         AS function_name,
    pf.type_desc,
    pf.boundary_value_on_right,
    pf.fanout                                       AS partition_count,
    prv.value                                       AS boundary_value,
    ROW_NUMBER() OVER (
        PARTITION BY pf.function_id
        ORDER BY prv.boundary_id
    )                                               AS boundary_number
FROM sys.partition_functions     pf
JOIN sys.partition_range_values  prv
    ON prv.function_id = pf.function_id
WHERE pf.name IN ('pf_monthly_datetime2', 'pf_quarterly_date')
ORDER BY pf.name, boundary_number;
GO

-- =============================================================================
-- MAINTENANCE: Adding future boundaries (run each January)
-- Never run without a corresponding ALTER PARTITION SCHEME first.
--
-- Step 1 — extend scheme to accommodate new partition:
-- ALTER PARTITION SCHEME ps_monthly_logs NEXT USED FG_LOGS;
--
-- Step 2 — add the new boundary:
-- ALTER PARTITION FUNCTION pf_monthly_datetime2()
--     SPLIT RANGE ('2027-01-01');
--
-- Step 3 — verify:
-- SELECT $PARTITION.pf_monthly_datetime2('2027-01-15') AS partition_number;
-- =============================================================================

PRINT '01_partition_function.sql: pf_monthly_datetime2 and pf_quarterly_date created.';
GO
