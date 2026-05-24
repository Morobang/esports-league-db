-- =============================================================================
-- FILE:    02_partition_scheme.sql
-- PURPOSE: Define partition schemes that map partition functions to filegroups
-- DEPENDS: 01_partition_function.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- PARTITION SCHEME CONCEPTS
--
-- A partition scheme maps each partition NUMBER to a FILEGROUP.
-- The partition function says "how many partitions and where the boundaries are."
-- The partition scheme says "which filegroup stores each partition."
--
-- ALL TO one filegroup:
--   Simple — all partitions land on FG_LOGS. No I/O separation.
--   Used when you care about partition elimination (query speed) more than I/O.
--
-- TO individual filegroups:
--   Older partitions → cheap/slow storage filegroup
--   Current month   → fast SSD filegroup
--   Requires a filegroup per partition — complex to manage.
--
-- In this database we use ALL TO FG_LOGS for simplicity.
-- For a production system with tiered storage you would map old partitions
-- to a FG_ARCHIVE filegroup backed by slower/cheaper disks.
-- =============================================================================

-- =============================================================================
-- ps_monthly_logs
-- Maps pf_monthly_datetime2 → FG_LOGS for all partitions.
-- Used by: ops.viewership_log, audit.log
-- fanout = 37 boundaries = 38 partitions (one before first, one after last)
-- =============================================================================

CREATE PARTITION SCHEME ps_monthly_logs
AS PARTITION pf_monthly_datetime2
ALL TO (FG_LOGS);
GO

-- =============================================================================
-- ps_quarterly_ops
-- Maps pf_quarterly_date → PRIMARY for operational tables.
-- Used by: future partitioned ops tables (e.g. ticket_order archive)
-- =============================================================================

CREATE PARTITION SCHEME ps_quarterly_ops
AS PARTITION pf_quarterly_date
ALL TO ([PRIMARY]);
GO

-- =============================================================================
-- Verify schemes and their filegroup mappings
-- =============================================================================

SELECT
    ps.name                                         AS scheme_name,
    pf.name                                         AS function_name,
    pf.fanout                                       AS total_partitions,
    ds.name                                         AS filegroup_name,
    dds.destination_id                              AS partition_number
FROM sys.partition_schemes          ps
JOIN sys.partition_functions        pf  ON pf.function_id = ps.function_id
JOIN sys.destination_data_spaces    dds ON dds.partition_scheme_id = ps.data_space_id
JOIN sys.data_spaces                ds  ON ds.data_space_id = dds.data_space_id
WHERE ps.name IN ('ps_monthly_logs', 'ps_quarterly_ops')
ORDER BY ps.name, dds.destination_id;
GO

-- =============================================================================
-- Check which partition a sample datetime falls into
-- =============================================================================

SELECT
    $PARTITION.pf_monthly_datetime2('2025-01-15 14:00:00') AS jan_2025_partition,
    $PARTITION.pf_monthly_datetime2('2025-08-10 22:00:00') AS aug_2025_partition,
    $PARTITION.pf_monthly_datetime2('2025-09-22 21:00:00') AS sep_2025_partition,
    $PARTITION.pf_monthly_datetime2('2026-01-01 00:00:00') AS jan_2026_partition;
GO

-- =============================================================================
-- Row count per partition (run after data is loaded)
-- Shows how data distributes across partitions
-- =============================================================================

SELECT
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    p.partition_number,
    p.rows                                          AS row_count,
    -- Determine the partition boundary dates
    CASE
        WHEN prv_left.value IS NULL
        THEN 'Before ' + CONVERT(NVARCHAR, prv_right.value, 120)
        WHEN prv_right.value IS NULL
        THEN CONVERT(NVARCHAR, prv_left.value, 120) + ' and later'
        ELSE CONVERT(NVARCHAR, prv_left.value, 120)
             + ' to ' + CONVERT(NVARCHAR, prv_right.value, 120)
    END                                             AS partition_range,
    fg.name                                         AS filegroup_name
FROM sys.partitions                 p
JOIN sys.indexes                    i
    ON  i.object_id  = p.object_id
    AND i.index_id   = p.index_id
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
WHERE OBJECT_NAME(i.object_id) IN ('viewership_log', 'log')
  AND i.index_id IN (0, 1)   -- heap or clustered only
  AND p.rows > 0              -- skip empty partitions
ORDER BY schema_name, table_name, p.partition_number;
GO

PRINT '02_partition_scheme.sql: ps_monthly_logs and ps_quarterly_ops created.';
GO
