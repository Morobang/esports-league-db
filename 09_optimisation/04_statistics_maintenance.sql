-- =============================================================================
-- FILE:    04_statistics_maintenance.sql
-- PURPOSE: Statistics health monitoring, manual update strategies,
--          and auto-update configuration for this database
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- WHY STATISTICS MATTER
-- ─────────────────────
-- The query optimiser uses statistics (histograms) to estimate how many rows
-- will match a predicate. Bad estimates → bad plan choices:
--
--   Estimated 10 rows, actual 100,000 rows
--   → Optimiser chose Nested Loops (good for small sets)
--   → Should have been Hash Match (better for large sets)
--   → Result: 100,000 nested loop iterations instead of one hash build
--
-- This is the #1 cause of "the query was fast yesterday, slow today."
-- Bulk inserts, large deletes, and partition switches all stale statistics.
--
-- SQL Server auto-updates statistics when ~20% of rows change (default).
-- On large tables (viewership_log, audit.log) 20% = millions of rows —
-- statistics can be significantly stale before auto-update triggers.
-- Set ASYNC_AUTO_UPDATE = ON so auto-updates don't block queries.
-- =============================================================================

-- =============================================================================
-- STEP 1: Configure auto-statistics for this database
-- =============================================================================

ALTER DATABASE EsportsLeague SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE EsportsLeague SET AUTO_UPDATE_STATISTICS_ASYNC ON;  -- non-blocking
ALTER DATABASE EsportsLeague SET AUTO_CREATE_STATISTICS ON;
GO

-- =============================================================================
-- STEP 2: Check statistics age and row modification counters
--
-- modification_counter = number of row changes since last stats update
-- A high counter on a small table = stale stats, update immediately
-- A high counter on a large table = may still be within 20% threshold
-- =============================================================================

SELECT
    OBJECT_SCHEMA_NAME(s.object_id)                 AS schema_name,
    OBJECT_NAME(s.object_id)                        AS table_name,
    s.name                                          AS stats_name,
    s.auto_created,
    s.user_created,
    sp.last_updated,
    sp.rows                                         AS total_rows,
    sp.rows_sampled,
    ROUND(100.0 * sp.rows_sampled / NULLIF(sp.rows, 0), 1)
                                                    AS sample_rate_pct,
    sp.modification_counter                         AS row_changes_since_update,
    ROUND(100.0 * sp.modification_counter / NULLIF(sp.rows, 0), 1)
                                                    AS change_pct,
    DATEDIFF(DAY, sp.last_updated, GETUTCDATE())    AS days_since_update,
    CASE
        WHEN sp.modification_counter > sp.rows * 0.20
        THEN 'UPDATE NOW — exceeds 20% threshold'
        WHEN DATEDIFF(DAY, sp.last_updated, GETUTCDATE()) > 7
        THEN 'REVIEW — older than 7 days'
        ELSE 'OK'
    END                                             AS recommendation
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECT_SCHEMA_NAME(s.object_id) IN ('comp','ops','audit')
  AND sp.rows > 0
ORDER BY sp.modification_counter DESC, sp.last_updated ASC;
GO

-- =============================================================================
-- STEP 3: Manual UPDATE STATISTICS — targeted by table
--
-- FULLSCAN    → reads every row, most accurate, most expensive
-- SAMPLE N%   → samples N% of rows, cheaper, less accurate
-- DEFAULT     → SQL Server chooses sample rate (often 1-5% for large tables)
--
-- Use FULLSCAN after: bulk loads, partition switches, initial data load
-- Use SAMPLE 30%  for: daily maintenance on large tables
-- Use DEFAULT     for: routine auto-maintenance jobs
-- =============================================================================

-- Update all stats on the hottest tables after data load:
UPDATE STATISTICS comp.player_stat     WITH FULLSCAN;
UPDATE STATISTICS comp.match           WITH FULLSCAN;
UPDATE STATISTICS comp.player_rating   WITH FULLSCAN;
UPDATE STATISTICS comp.team_standing   WITH FULLSCAN;
UPDATE STATISTICS ops.viewership_log   WITH FULLSCAN;
UPDATE STATISTICS ops.ticket_order     WITH FULLSCAN;
GO

-- Update all stats on the partitioned tables (after migration in 08_partitioning):
UPDATE STATISTICS ops.viewership_log_partitioned WITH FULLSCAN;
UPDATE STATISTICS audit.log_partitioned          WITH FULLSCAN;
GO

-- =============================================================================
-- STEP 4: UPDATE STATISTICS on a specific index (more targeted)
--         Useful when you know one index's stats are stale
-- =============================================================================

-- Update only the stats for a specific index:
UPDATE STATISTICS comp.player_stat IX_pstat_player_id WITH FULLSCAN;
UPDATE STATISTICS comp.match       IX_match_tournament_id WITH SAMPLE 50 PERCENT;
GO

-- =============================================================================
-- STEP 5: sp_updatestats — updates ALL tables in the database
--         Only updates tables with row changes since last update.
--         Faster than full UPDATE STATISTICS sweep but less accurate.
--         Good for: daily maintenance job in SQL Agent.
-- =============================================================================

-- EXEC sp_updatestats;  -- uncomment to run
GO

-- =============================================================================
-- STEP 6: Histogram inspection — what does SQL Server actually know
--         about a column's value distribution?
-- =============================================================================

-- Check histogram for match.tournament_id
-- (Tells us if cardinality estimates for tournament_id = 12 will be accurate)
DBCC SHOW_STATISTICS ('comp.match', 'IX_match_tournament_id')
    WITH HISTOGRAM;
GO
-- Output columns:
-- RANGE_HI_KEY → upper boundary of the histogram step
-- RANGE_ROWS   → estimated rows with values between previous and current step
-- EQ_ROWS      → estimated rows equal to RANGE_HI_KEY
-- DISTINCT_RANGE_ROWS → distinct values in the range
-- AVG_RANGE_ROWS → average rows per distinct value in range
--
-- If tournament_id = 12 has EQ_ROWS = 3 but actual = 10, stats are stale.
-- Update with FULLSCAN and re-check.

-- Check histogram for player.status (low-cardinality column)
DBCC SHOW_STATISTICS ('comp.player', 'IX_filter_player_active')
    WITH HISTOGRAM;
GO
-- For a filtered index, the histogram only covers rows matching the filter.
-- EQ_ROWS for 'Active' should match the actual active player count.

-- =============================================================================
-- STEP 7: Trace flag 2371 — lower auto-update threshold for large tables
--
-- SQL Server 2014 and earlier: auto-update threshold = SQRT(1000 * table_rows)
-- SQL Server 2016+ (compat 130+): dynamic threshold already improved
-- This database is compat 150 (SQL Server 2019) — dynamic threshold active.
-- No trace flag needed, but document it for older environments.
--
-- For SQL Server 2014 or compat < 130 on large tables:
-- DBCC TRACEON (2371, -1);  -- enables dynamic statistics threshold globally
-- =============================================================================

-- =============================================================================
-- STEP 8: SQL Agent job template for weekly statistics maintenance
-- Paste this as the job step command in SQL Agent
-- =============================================================================

/*
USE EsportsLeague;

-- Update stats on tables with > 10% row modification since last update
DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql += 'UPDATE STATISTICS '
    + OBJECT_SCHEMA_NAME(s.object_id) + '.'
    + OBJECT_NAME(s.object_id)
    + ' WITH SAMPLE 30 PERCENT;' + CHAR(13)
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECT_SCHEMA_NAME(s.object_id) IN ('comp','ops','audit')
  AND sp.rows > 0
  AND sp.modification_counter > sp.rows * 0.10   -- 10% threshold
  AND sp.last_updated < DATEADD(DAY, -1, GETUTCDATE()); -- not updated today

EXEC sp_executesql @sql;
*/

-- =============================================================================
-- STEP 9: Query Store — enabled for deeper query plan tracking
--
-- Query Store persists plan history across restarts (unlike DMVs).
-- Enables: plan forcing, regression detection, top resource consumers.
-- =============================================================================

ALTER DATABASE EsportsLeague
SET QUERY_STORE = ON (
    OPERATION_MODE        = READ_WRITE,
    CLEANUP_POLICY        = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB   = 500,
    QUERY_CAPTURE_MODE    = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO
);
GO

-- Find regressed queries (plan changed and got worse):
SELECT TOP 10
    qsq.query_id,
    qsq.query_hash,
    qsp.plan_id,
    qsrs.avg_duration / 1000.0                      AS avg_duration_ms,
    qsrs.avg_logical_io_reads                       AS avg_logical_reads,
    qsrs.count_executions,
    TRY_CAST(qsp.query_plan AS XML)                 AS query_plan_xml
FROM sys.query_store_query            qsq
JOIN sys.query_store_plan             qsp  ON qsp.query_id  = qsq.query_id
JOIN sys.query_store_runtime_stats    qsrs ON qsrs.plan_id  = qsp.plan_id
JOIN sys.query_store_runtime_stats_interval qsrsi
    ON qsrsi.runtime_stats_interval_id = qsrs.runtime_stats_interval_id
WHERE qsrsi.start_time > DATEADD(HOUR, -24, GETUTCDATE())  -- last 24 hours
ORDER BY qsrs.avg_duration DESC;
GO

PRINT '04_statistics_maintenance.sql loaded.';
GO
