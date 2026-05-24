-- =============================================================================
-- FILE:    01_clustered_indexes.sql
-- PURPOSE: Document and review clustered index decisions made at table creation.
--          Rebuild/reorganise commands for maintenance.
-- NOTE:    All clustered indexes were defined inline in 01_schema/ via PRIMARY KEY
--          CLUSTERED. This file documents the rationale and provides maintenance
--          commands. No new clustered indexes are created here.
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- CLUSTERED INDEX DECISIONS — RATIONALE
-- =============================================================================
--
-- TABLE                   | CLUSTERED ON          | REASON
-- ------------------------|-----------------------|-----------------------------
-- comp.game               | game_id               | Small lookup table, PK fine
-- comp.region             | region_id             | Tiny table
-- comp.league             | league_id             | Queried by FK joins
-- comp.team               | team_id               | FK target — wide join usage
-- comp.player             | player_id             | FK target — very high join freq
-- comp.staff              | staff_id              | Low volume
-- comp.contract           | contract_id           | History table, insert order ok
-- comp.tournament         | tournament_id         | FK target
-- comp.tournament_team    | (tournament_id,team_id)| Natural composite PK
-- comp.match              | match_id              | High join volume on match_id
-- comp.match_map          | map_id                | Sequential per match
-- comp.player_stat        | stat_id  (FG_STATS)   | Insert order; filtered by match/player via NC
-- comp.player_rating      | rating_id (FG_STATS)  | One row per player+tournament
-- comp.team_standing      | standing_id           | Low volume; queried via NC on league_id
-- ops.venue               | venue_id              | Lookup table
-- ops.event               | event_id              | Queried by tournament_id via NC
-- ops.ticket_tier         | tier_id               | FK target for ticket_order
-- ops.fan                 | fan_id                | High volume; email/username via NC
-- ops.ticket_order        | order_id              | Insert order; filtered by fan/tier via NC
-- ops.sponsor             | sponsor_id            | Lookup table
-- ops.sponsorship         | sponsorship_id        | Queried by sponsor/team/tournament via NC
-- ops.broadcaster         | broadcaster_id        | Lookup table
-- ops.broadcast_rights    | rights_id             | Queried by tournament_id via NC
-- ops.viewership_log      | (log_id, logged_at)   | Partition-aligned composite PK
-- audit.log               | (log_id, changed_at)  | Partition-aligned composite PK
--
-- KEY PRINCIPLE:
-- High-volume FK target tables (player, team, match) use integer surrogate PKs
-- as clustered keys — small, monotonically increasing, ideal for range scans
-- and join performance. The composite PKs on tournament_team and viewership_log
-- are partition-aware by design.
-- =============================================================================

-- =============================================================================
-- MAINTENANCE: Rebuild all clustered indexes (run during off-peak window)
-- =============================================================================

-- Check fragmentation first
SELECT
    OBJECT_SCHEMA_NAME(ips.object_id)           AS schema_name,
    OBJECT_NAME(ips.object_id)                  AS table_name,
    i.name                                      AS index_name,
    ips.index_type_desc,
    ROUND(ips.avg_fragmentation_in_percent, 1)  AS fragmentation_pct,
    ips.page_count
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
JOIN sys.indexes i
    ON ips.object_id = i.object_id
    AND ips.index_id = i.index_id
WHERE ips.index_type_desc = 'CLUSTERED INDEX'
  AND ips.page_count > 100
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

-- Rebuild strategy:
--   < 10% fragmentation  → skip
--   10–30%               → REORGANIZE (online, minimal locking)
--   > 30%                → REBUILD (takes more time, full defrag)

-- REORGANIZE example (online, low impact):
-- ALTER INDEX PK_player_stat ON comp.player_stat REORGANIZE;

-- REBUILD example (offline or online edition):
-- ALTER INDEX PK_match ON comp.match
--     REBUILD WITH (ONLINE = ON, FILLFACTOR = 90);

-- REBUILD ALL indexes on a table:
-- ALTER INDEX ALL ON comp.player_stat
--     REBUILD WITH (ONLINE = ON, FILLFACTOR = 85, SORT_IN_TEMPDB = ON);

-- =============================================================================
-- FILL FACTOR GUIDE for this database
-- =============================================================================
-- comp.player_stat    → FILLFACTOR = 80  (high insert rate, leaves room)
-- audit.log           → FILLFACTOR = 95  (append-only, minimal page splits)
-- comp.team           → FILLFACTOR = 90  (low churn)
-- ops.ticket_order    → FILLFACTOR = 85  (moderate insert rate)
-- All others          → FILLFACTOR = 90  (default safe choice)

PRINT 'Clustered index review and maintenance script loaded.';
GO
