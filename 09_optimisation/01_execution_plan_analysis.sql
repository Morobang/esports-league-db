-- =============================================================================
-- FILE:    01_execution_plan_analysis.md (saved as .sql for consistency)
-- PURPOSE: Guide to reading execution plans in this database,
--          with specific queries to analyse and what to look for
-- =============================================================================

/*
===============================================================================
EXECUTION PLAN ANALYSIS — EsportsLeague Database
===============================================================================

HOW TO ENABLE PLANS IN SSMS
-----------------------------
Estimated plan : CTRL + L  (no query execution)
Actual plan    : CTRL + M  (enable), then run query
XML plan       : SET STATISTICS XML ON; <query>; SET STATISTICS XML OFF;
Text plan      : SET STATISTICS PROFILE ON; <query>; SET STATISTICS PROFILE OFF;

Always use ACTUAL plans for tuning — estimated row counts are often wrong,
and the actual vs estimated gap tells you where statistics are stale.

KEY OPERATORS TO RECOGNISE
---------------------------
Clustered Index Seek   → best case: uses the clustered key directly
Nonclustered Index Seek → good: uses an NC index, may do key lookup
Index Scan             → reads the entire index — often a red flag
Table Scan             → no usable index found — always investigate
Key Lookup             → NC index found the row, but fetched columns
                         not in INCLUDE list → add to index or use covering index
Hash Match (Join)      → used for large unsorted inputs, memory-intensive
Merge Join             → fast for pre-sorted inputs (good with indexes)
Nested Loop            → best for small outer inputs with indexed inner
Sort                   → expensive if not avoided by index order
Parallelism (DOP>1)    → good for large queries, bad for OLTP
Spool                  → SQL Server cached an intermediate result —
                         often signals a missing index or bad join order

COST NUMBERS
------------
The % cost on each operator is relative to the plan, not wall-clock time.
A 90% cost operator is not necessarily slow — it may just dominate a fast plan.
Always cross-reference with SET STATISTICS TIME ON output for real durations.

READING THE PLAN TREE
---------------------
Execution plans read RIGHT TO LEFT, BOTTOM TO TOP.
Data flows from leaf operators (scans/seeks) up to the root (SELECT/INSERT).
The width of connecting arrows represents estimated row count — thin = few rows.
A thick arrow going into a filter is a sign the filter should be pushed earlier
(missing index or predicate order issue).

===============================================================================
QUERY PLAN WALKTHROUGHS — THIS DATABASE
===============================================================================
*/

USE EsportsLeague;
GO

-- Enable timing for all queries below
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- =============================================================================
-- PLAN 1: Simple seek — should show Clustered Index Seek + Key Lookup
--         Goal: verify IX_cover_active_roster eliminates the key lookup
-- =============================================================================

-- WITHOUT covering index (force scan to compare):
SELECT username, real_name, nationality, role, joined_at
FROM comp.player WITH (INDEX = 0)   -- hint: ignore all NC indexes
WHERE team_id = 1
  AND status  = 'Active';
GO

-- WITH covering index (should be Index Seek, no Key Lookup):
SELECT username, real_name, nationality, role, joined_at
FROM comp.player
WHERE team_id = 1
  AND status  = 'Active';
GO
-- Compare: logical reads in STATISTICS IO output. The WITH (INDEX=0) version
-- should show many more logical reads (full table scan or clustered scan).

-- =============================================================================
-- PLAN 2: Join fan-out — match + player_stat
--         Look for: Hash Match vs Nested Loop vs Merge Join
--         Goal: show how index on player_stat.match_id affects join strategy
-- =============================================================================

-- Check estimated vs actual rows on the player_stat seek
SELECT
    m.match_id,
    m.stage,
    m.played_at,
    ps.player_id,
    ps.kills,
    ps.damage_dealt,
    ps.mvp_flag
FROM comp.match       m
JOIN comp.player_stat ps ON ps.match_id = m.match_id
WHERE m.tournament_id = 12
  AND m.status        = 'Completed'
ORDER BY m.played_at, ps.kills DESC;
GO
-- In the plan: match is seeked via IX_match_tournament_id,
-- player_stat is seeked via IX_cover_stat_by_match.
-- Should be Nested Loops (small outer = matches, large inner = stats per match).
-- If you see Hash Match here, statistics on player_stat may be stale → UPDATE STATISTICS.

-- =============================================================================
-- PLAN 3: The vw_tournament_summary view — the most complex plan in the system
--         Goal: identify which CTE materialisation is most expensive
-- =============================================================================

SELECT
    tournament_name,
    winner_name,
    total_matches,
    peak_viewers_global,
    total_ticket_revenue,
    estimated_total_revenue
FROM comp.vw_tournament_summary
WHERE status = 'Completed'
ORDER BY estimated_total_revenue DESC;
GO
-- What to look for:
-- 1. The ticket_revenue CTE likely shows a Hash Match Aggregate — normal
-- 2. The viewership_totals CTE may show a Clustered Index Scan on viewership_log
--    → this is where partitioned table shows its value (partition elimination)
-- 3. The final GROUP BY may show a Sort operator — could be avoided with
--    an indexed view materialising the base aggregations
-- 4. Note total logical reads — this is your baseline before any rewrites in file 03

-- =============================================================================
-- PLAN 4: Window function plan — player leaderboard
--         Goal: understand how SQL Server executes multiple OVER() clauses
-- =============================================================================

SELECT
    tournament_name,
    username,
    total_kills,
    total_damage,
    kills_rank,
    kda_rank,
    damage_rank
FROM comp.vw_player_leaderboard
WHERE tournament_id = 12
ORDER BY kills_rank;
GO
-- What to look for:
-- 1. Segment + Sequence Project operators implement each window function
-- 2. Three window functions on the same partition may share one Sort pass
--    (SQL Server is smart enough to reuse sorted input)
-- 3. If you see three separate Sort operators — statistics are likely stale
--    and row estimates are wrong, causing a bad plan choice

-- =============================================================================
-- PLAN 5: Partition elimination confirmation
--         Goal: verify viewership_log_partitioned scans only relevant partitions
-- =============================================================================

SELECT
    vl.log_id,
    vl.peak_viewers,
    vl.logged_at
FROM ops.viewership_log_partitioned vl
WHERE vl.logged_at >= '2025-08-01'
  AND vl.logged_at <  '2025-09-01';
GO
-- In the actual plan:
-- Hover over the Clustered Index Scan/Seek operator
-- Properties panel → "Actual Partition Count" should be 1
-- "Actual Partitions Accessed" should show only partition 20 (Aug 2025)
-- If it shows all 38 partitions → the predicate is not SARGable
-- (check for implicit conversions or function wrapping on logged_at)

-- =============================================================================
-- PLAN 6: Key lookup elimination test
--         Goal: show the cost difference with and without INCLUDE columns
-- =============================================================================

-- Force a key lookup by querying a column NOT in the index INCLUDE list:
SELECT
    o.order_id,
    o.fan_id,
    o.tier_id,
    o.quantity,
    o.total_amount,
    o.payment_ref    -- this column is NOT in IX_order_fan_id's INCLUDE list
FROM ops.ticket_order o
WHERE o.fan_id = 4;
GO
-- You will see: NC Index Seek (IX_order_fan_id) + Key Lookup (for payment_ref)
-- The Key Lookup is a nested loop back to the clustered index per qualifying row.
-- Fix: add payment_ref to the INCLUDE list of IX_order_fan_id (see 03_query_rewrites.sql)

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '01_execution_plan_analysis.sql loaded.';
GO
