-- =============================================================================
-- FILE:    03_query_rewrites.sql
-- PURPOSE: Before/after query rewrites with explanations.
--          Each rewrite targets a specific anti-pattern found in this database.
-- =============================================================================

USE EsportsLeague;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- =============================================================================
-- REWRITE 1: Non-SARGable predicate → SARGable
--
-- PROBLEM: Wrapping the partition key in a function breaks partition elimination
--          and prevents index seeks. SQL Server cannot invert the function to
--          match it against stored index values.
-- =============================================================================

-- ❌ BEFORE: YEAR() wraps the column — forces a scan across all partitions
SELECT COUNT(*)
FROM ops.viewership_log_partitioned
WHERE YEAR(logged_at) = 2025
  AND MONTH(logged_at) = 8;
GO

-- ✅ AFTER: Range predicate on the raw column — SARGable, partition elimination
SELECT COUNT(*)
FROM ops.viewership_log_partitioned
WHERE logged_at >= '2025-08-01'
  AND logged_at <  '2025-09-01';
GO
-- IO difference: AFTER version touches 1 partition.
-- BEFORE version scans all 38 partitions.
-- Rule: never wrap an indexed column in a function on the WHERE side.
--       Transform the constant instead (DATEADD, literal ranges).

-- =============================================================================
-- REWRITE 2: COUNT(*) with NOT EXISTS vs LEFT JOIN / WHERE IS NULL
--
-- PROBLEM: LEFT JOIN + WHERE IS NULL works but creates a larger intermediate
--          result set. NOT EXISTS short-circuits on first match and is
--          typically faster, especially with an index on the inner table.
-- =============================================================================

-- ❌ BEFORE: LEFT JOIN anti-join pattern
SELECT t.name AS team_name, t.team_id
FROM comp.team t
LEFT JOIN ops.sponsorship sp
    ON sp.team_id = t.team_id
    AND sp.status = 'Active'
WHERE sp.sponsorship_id IS NULL
  AND t.is_active = 1;
GO

-- ✅ AFTER: NOT EXISTS anti-join — stops searching on first match per team
SELECT t.name AS team_name, t.team_id
FROM comp.team t
WHERE t.is_active = 1
  AND NOT EXISTS (
      SELECT 1
      FROM ops.sponsorship sp
      WHERE sp.team_id = t.team_id
        AND sp.status  = 'Active'
  );
GO
-- For small tables the difference is negligible.
-- For large sponsorship tables: NOT EXISTS uses IX_filter_sponsorship_active
-- and stops at first hit per team. LEFT JOIN reads all matching rows.

-- =============================================================================
-- REWRITE 3: Implicit conversion — data type mismatch kills index seeks
--
-- PROBLEM: Comparing an INT column to a VARCHAR literal forces SQL Server
--          to convert every stored INT to VARCHAR for comparison.
--          This causes a scan instead of a seek.
-- =============================================================================

-- ❌ BEFORE: fan_id is INT but passed as VARCHAR-equivalent expression
-- (simulated here with CAST on the column side — same problem)
SELECT fan_id, username, email
FROM ops.fan
WHERE CAST(fan_id AS NVARCHAR) = '4';
GO

-- ✅ AFTER: Match the column's data type exactly
SELECT fan_id, username, email
FROM ops.fan
WHERE fan_id = 4;
GO
-- The first query forces a scan. The second uses the clustered index seek.
-- Common real-world version: ORM passes string '4' to an INT column parameter.
-- Fix at the application layer or with CONVERT on the parameter, never the column.

-- =============================================================================
-- REWRITE 4: Correlated subquery → JOIN
--
-- PROBLEM: A correlated subquery re-executes for every row in the outer query.
--          With 10,000 players and a subquery hitting player_stat, that is
--          10,000 separate executions. A JOIN executes once.
-- =============================================================================

-- ❌ BEFORE: Correlated subquery — executes once per player row
SELECT
    p.player_id,
    p.username,
    (
        SELECT SUM(ps.kills)
        FROM comp.player_stat ps
        JOIN comp.match m ON m.match_id = ps.match_id
        WHERE ps.player_id = p.player_id
          AND m.status = 'Completed'
    ) AS career_kills
FROM comp.player p
WHERE p.status = 'Active';
GO

-- ✅ AFTER: Aggregate JOIN — one pass over player_stat
SELECT
    p.player_id,
    p.username,
    COALESCE(SUM(ps.kills), 0)                      AS career_kills
FROM comp.player p
LEFT JOIN comp.player_stat ps ON ps.player_id = p.player_id
LEFT JOIN comp.match        m  ON m.match_id   = ps.match_id
                              AND m.status     = 'Completed'
WHERE p.status = 'Active'
GROUP BY p.player_id, p.username;
GO
-- The JOIN version produces one Hash Match Aggregate over all stats at once.
-- The correlated version shows "Nested Loops" with "Execute 1 time per row"
-- in the plan — the smoking gun for correlated subquery overhead.

-- =============================================================================
-- REWRITE 5: SELECT * → explicit column list
--
-- PROBLEM: SELECT * fetches all columns including large NVARCHAR(MAX) columns
--          (old_value, new_value in audit.log). This bloats network transfer
--          and prevents covering index usage entirely.
-- =============================================================================

-- ❌ BEFORE: SELECT * — pulls NVARCHAR(MAX) columns unnecessarily
SELECT *
FROM audit.log
WHERE table_name = 'contract'
  AND operation  = 'UPDATE'
ORDER BY changed_at DESC;
GO

-- ✅ AFTER: Only the columns the query consumer actually needs
SELECT
    log_id,
    table_name,
    operation,
    record_id,
    changed_by,
    app_context,
    changed_at
FROM audit.log
WHERE table_name = 'contract'
  AND operation  = 'UPDATE'
ORDER BY changed_at DESC;
GO
-- The AFTER version can be served entirely by IX_audit_table_operation
-- (which includes record_id, changed_by, changed_at).
-- The BEFORE version always needs a Key Lookup for old_value/new_value.

-- =============================================================================
-- REWRITE 6: OR on different columns → UNION ALL
--
-- PROBLEM: OR across two different columns prevents index seeks on either.
--          SQL Server often falls back to a table scan.
--          UNION ALL lets each branch use its own index seek.
-- =============================================================================

-- ❌ BEFORE: OR across team_a_id and team_b_id
SELECT match_id, tournament_id, team_a_id, team_b_id, winner_id, played_at
FROM comp.match
WHERE (team_a_id = 11 OR team_b_id = 11)
  AND status = 'Completed';
GO

-- ✅ AFTER: UNION ALL — each branch uses its own NC index seek
SELECT match_id, tournament_id, team_a_id, team_b_id, winner_id, played_at
FROM comp.match
WHERE team_a_id = 11
  AND status    = 'Completed'

UNION ALL

SELECT match_id, tournament_id, team_a_id, team_b_id, winner_id, played_at
FROM comp.match
WHERE team_b_id = 11
  AND status    = 'Completed';
GO
-- Before: one plan, likely Index Scan (OR prevents seek on both indexes)
-- After:  two seeks — IX_match_team_a for first branch,
--                     IX_match_team_b for second branch.
-- The duplicate row risk (team_a = team_b = 11) doesn't apply here
-- since a team can't play itself, but add EXCEPT or DISTINCT if needed.

-- =============================================================================
-- REWRITE 7: Paging with OFFSET/FETCH vs old TOP + subquery pattern
--
-- PROBLEM: Old ROW_NUMBER() paging subquery is verbose and reads more rows.
--          OFFSET/FETCH is cleaner and the optimiser handles it well
--          when backed by an ordered index.
-- =============================================================================

DECLARE @page      INT = 2;
DECLARE @page_size INT = 10;

-- ❌ BEFORE: ROW_NUMBER subquery paging
SELECT *
FROM (
    SELECT
        p.player_id, p.username, p.role,
        t.name AS team_name,
        ROW_NUMBER() OVER (ORDER BY p.username) AS rn
    FROM comp.player p
    JOIN comp.team   t ON t.team_id = p.team_id
    WHERE p.status = 'Active'
) paged
WHERE rn BETWEEN (@page - 1) * @page_size + 1
              AND @page * @page_size;
GO

-- ✅ AFTER: OFFSET/FETCH — cleaner, same performance, index-friendly
DECLARE @page2      INT = 2;
DECLARE @page_size2 INT = 10;

SELECT
    p.player_id,
    p.username,
    p.role,
    t.name AS team_name
FROM comp.player p
JOIN comp.team   t ON t.team_id = p.team_id
WHERE p.status = 'Active'
ORDER BY p.username
OFFSET  (@page2 - 1) * @page_size2 ROWS
FETCH NEXT @page_size2 ROWS ONLY;
GO

-- =============================================================================
-- REWRITE 8: Add INCLUDE column to eliminate key lookup
--            (from the Plan 6 finding in 01_execution_plan_analysis.sql)
-- =============================================================================

-- The original IX_order_fan_id does not include payment_ref.
-- Add it to eliminate the key lookup identified in Plan 6.

DROP INDEX IF EXISTS IX_order_fan_id ON ops.ticket_order;
GO

CREATE NONCLUSTERED INDEX IX_order_fan_id
    ON ops.ticket_order (fan_id)
    INCLUDE (tier_id, quantity, total_amount, status, ordered_at, payment_ref);
-- Added payment_ref to the INCLUDE list.
GO

-- Verify: re-run Plan 6 query from 01_execution_plan_analysis.sql
-- Key Lookup should now be gone.
SELECT
    o.order_id,
    o.fan_id,
    o.tier_id,
    o.quantity,
    o.total_amount,
    o.payment_ref
FROM ops.ticket_order o
WHERE o.fan_id = 4;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '03_query_rewrites.sql loaded.';
GO
