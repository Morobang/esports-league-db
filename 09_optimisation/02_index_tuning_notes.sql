-- =============================================================================
-- FILE:    02_index_tuning_notes.sql
-- PURPOSE: Queries to find missing indexes, unused indexes, duplicate indexes,
--          and the most expensive queries by index usage
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- SECTION 1: Missing index recommendations from the DMVs
--
-- SQL Server tracks queries that would benefit from an index it didn't have.
-- sys.dm_db_missing_index_details  → what columns to add
-- sys.dm_db_missing_index_groups   → groups recommendations
-- sys.dm_db_missing_index_group_stats → how much benefit is estimated
--
-- improvement_measure = seeks * avg_user_impact
-- Higher = more valuable. Prioritise > 100,000 before anything else.
-- =============================================================================

SELECT TOP 20
    ROUND(migs.avg_total_user_cost
          * migs.avg_user_impact
          * (migs.user_seeks + migs.user_scans), 0)
                                                    AS improvement_measure,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_user_impact,
    OBJECT_SCHEMA_NAME(mid.object_id)               AS schema_name,
    OBJECT_NAME(mid.object_id)                      AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    -- Suggested CREATE INDEX statement
    CONCAT(
        'CREATE NONCLUSTERED INDEX IX_missing_',
        OBJECT_NAME(mid.object_id), '_',
        ROW_NUMBER() OVER (ORDER BY
            migs.avg_total_user_cost * migs.avg_user_impact
            * (migs.user_seeks + migs.user_scans) DESC),
        ' ON ', OBJECT_SCHEMA_NAME(mid.object_id), '.', OBJECT_NAME(mid.object_id),
        ' (', ISNULL(mid.equality_columns, ''),
        CASE WHEN mid.inequality_columns IS NOT NULL
             THEN CASE WHEN mid.equality_columns IS NOT NULL
                       THEN ', ' ELSE '' END
                  + mid.inequality_columns
             ELSE '' END,
        ')',
        CASE WHEN mid.included_columns IS NOT NULL
             THEN ' INCLUDE (' + mid.included_columns + ')'
             ELSE ''
        END, ';'
    )                                               AS suggested_ddl
FROM sys.dm_db_missing_index_group_stats   migs
JOIN sys.dm_db_missing_index_groups        mig
    ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details       mid
    ON mid.index_handle = mig.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;
GO

-- =============================================================================
-- SECTION 2: Unused indexes — indexes that have never been sought or scanned
--            by user queries since last service restart
--
-- Caution: DMVs reset on service restart. Run this only after a representative
-- workload period (1+ weeks in production, or after running all queries in
-- this project). Do NOT drop indexes solely based on zero seeks if the server
-- was recently restarted.
-- =============================================================================

SELECT
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc,
    COALESCE(s.user_seeks,  0)                      AS user_seeks,
    COALESCE(s.user_scans,  0)                      AS user_scans,
    COALESCE(s.user_lookups,0)                      AS user_lookups,
    COALESCE(s.user_updates,0)                      AS user_updates,  -- write overhead
    s.last_user_seek,
    s.last_user_scan,
    -- Indexes with high writes but zero reads are pure overhead
    CASE
        WHEN COALESCE(s.user_seeks + s.user_scans + s.user_lookups, 0) = 0
             AND COALESCE(s.user_updates, 0) > 0
        THEN 'DROP CANDIDATE — write overhead only'
        WHEN COALESCE(s.user_seeks + s.user_scans + s.user_lookups, 0) = 0
        THEN 'REVIEW — never used'
        ELSE 'Active'
    END                                             AS recommendation
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
    ON  s.object_id  = i.object_id
    AND s.index_id   = i.index_id
    AND s.database_id = DB_ID()
WHERE OBJECT_SCHEMA_NAME(i.object_id) IN ('comp','ops','audit')
  AND i.index_id > 1              -- skip clustered indexes
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
ORDER BY COALESCE(s.user_seeks + s.user_scans, 0) ASC,
         COALESCE(s.user_updates, 0) DESC;
GO

-- =============================================================================
-- SECTION 3: Duplicate / overlapping indexes
--            Indexes with the same leading key column on the same table
--            are candidates for consolidation
-- =============================================================================

WITH index_columns AS (
    SELECT
        i.object_id,
        i.index_id,
        i.name                                      AS index_name,
        i.type_desc,
        -- Build a comma-separated key column list
        STRING_AGG(c.name, ', ')
            WITHIN GROUP (ORDER BY ic.key_ordinal)  AS key_cols,
        -- First key column only (for overlap detection)
        MIN(CASE WHEN ic.key_ordinal = 1 THEN c.name END)
                                                    AS first_key_col
    FROM sys.indexes           i
    JOIN sys.index_columns     ic ON ic.object_id = i.object_id
                                 AND ic.index_id  = i.index_id
                                 AND ic.is_included_column = 0
    JOIN sys.columns           c  ON c.object_id  = ic.object_id
                                 AND c.column_id  = ic.column_id
    WHERE OBJECT_SCHEMA_NAME(i.object_id) IN ('comp','ops','audit')
      AND i.index_id > 0
    GROUP BY i.object_id, i.index_id, i.name, i.type_desc
)
SELECT
    OBJECT_SCHEMA_NAME(a.object_id)                 AS schema_name,
    OBJECT_NAME(a.object_id)                        AS table_name,
    a.index_name                                    AS index_a,
    b.index_name                                    AS index_b,
    a.key_cols                                      AS index_a_keys,
    b.key_cols                                      AS index_b_keys,
    a.first_key_col                                 AS shared_leading_key,
    'Review for consolidation'                      AS recommendation
FROM index_columns a
JOIN index_columns b
    ON  b.object_id     = a.object_id
    AND b.index_id      > a.index_id     -- avoid self-join duplicates
    AND b.first_key_col = a.first_key_col -- same leading key
    AND a.type_desc     = 'NONCLUSTERED'
    AND b.type_desc     = 'NONCLUSTERED'
ORDER BY OBJECT_NAME(a.object_id), a.first_key_col;
GO

-- =============================================================================
-- SECTION 4: Most fragmented indexes — candidates for REBUILD or REORGANIZE
-- =============================================================================

SELECT
    OBJECT_SCHEMA_NAME(ips.object_id)               AS schema_name,
    OBJECT_NAME(ips.object_id)                      AS table_name,
    i.name                                          AS index_name,
    i.type_desc,
    ROUND(ips.avg_fragmentation_in_percent, 1)      AS fragmentation_pct,
    ips.page_count,
    ips.record_count,
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30
        THEN CONCAT('ALTER INDEX ', i.name,
                    ' ON ', OBJECT_SCHEMA_NAME(ips.object_id), '.',
                    OBJECT_NAME(ips.object_id), ' REBUILD WITH (ONLINE=ON);')
        WHEN ips.avg_fragmentation_in_percent > 10
        THEN CONCAT('ALTER INDEX ', i.name,
                    ' ON ', OBJECT_SCHEMA_NAME(ips.object_id), '.',
                    OBJECT_NAME(ips.object_id), ' REORGANIZE;')
        ELSE 'No action needed'
    END                                             AS recommended_action
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'LIMITED')           AS ips
JOIN sys.indexes i
    ON  i.object_id = ips.object_id
    AND i.index_id  = ips.index_id
WHERE ips.database_id = DB_ID()
  AND ips.page_count  > 100          -- ignore tiny indexes
  AND i.index_id > 0
  AND OBJECT_SCHEMA_NAME(ips.object_id) IN ('comp','ops','audit')
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

-- =============================================================================
-- SECTION 5: Top 10 most expensive queries by total logical reads
--            (requires Query Store or sys.dm_exec_query_stats)
-- =============================================================================

SELECT TOP 10
    qs.total_logical_reads                          AS total_logical_reads,
    qs.execution_count,
    ROUND(qs.total_logical_reads * 1.0
          / qs.execution_count, 0)                  AS avg_logical_reads,
    qs.total_elapsed_time / 1000                    AS total_elapsed_ms,
    ROUND(qs.total_elapsed_time * 1.0
          / qs.execution_count / 1000, 2)           AS avg_elapsed_ms,
    qs.total_worker_time / 1000                     AS total_cpu_ms,
    -- First 200 chars of the query text
    SUBSTRING(qt.text,
        (qs.statement_start_offset / 2) + 1,
        CASE qs.statement_end_offset
            WHEN -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2 + 1)  AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qt.dbid = DB_ID()
ORDER BY qs.total_logical_reads DESC;
GO

-- =============================================================================
-- SECTION 6: Index maintenance decision matrix — quick reference
-- =============================================================================
/*
    Fragmentation    Page Count    Action
    ─────────────    ──────────    ──────────────────────────────
    < 10%            Any           None
    10–30%           < 1000        REORGANIZE (online, low impact)
    10–30%           >= 1000       REORGANIZE or REBUILD (schedule off-peak)
    > 30%            Any           REBUILD (WITH ONLINE=ON if Enterprise)
    Any              < 100 pages   None (SQL Server ignores small indexes)

    REBUILD     → full defrag, updates statistics, resets fill factor
                  takes schema lock on Standard edition (blocking)
                  WITH ONLINE=ON on Enterprise avoids blocking
    REORGANIZE  → partial defrag, leaf-level only, no statistics update
                  always online, can be interrupted and resumed

    Schedule in SQL Agent:
    - REORGANIZE: weekly, off-peak
    - REBUILD:    monthly, maintenance window
    - UPDATE STATISTICS: after bulk loads, before critical report runs
*/

PRINT '02_index_tuning_notes.sql loaded.';
GO
