-- =============================================================================
-- FILE:    04_filtered_indexes.sql
-- PURPOSE: Filtered (partial) indexes on selective, high-value predicates.
--          Smaller than full indexes, faster for targeted queries.
-- DEPENDS: 01_schema/, 02_nonclustered_indexes.sql
-- =============================================================================
--
-- A FILTERED INDEX only indexes rows matching a WHERE predicate.
-- When most queries target a small subset of rows (e.g. status = 'Active'),
-- a filtered index is dramatically smaller and faster than a full index.
--
-- Rules for filtered indexes in SQL Server:
--   1. The filter predicate must use simple comparisons (=, <>, IS NULL, IS NOT NULL)
--   2. Queries using the index MUST include the filter column in WHERE or be
--      able to prove the filter is satisfied
--   3. Statistics are maintained separately per filtered index
--   4. Not usable with parameterised queries unless OPTION (RECOMPILE) is added
--      or the query has a literal predicate matching the filter
--
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.player — Active players only
-- Most roster queries only care about is_active/status = 'Active'.
-- Full table scans on a growing player history table are wasteful.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_player_active
    ON comp.player (team_id, role)
    INCLUDE (username, real_name, nationality, joined_at)
    WHERE status = 'Active';
GO

-- =============================================================================
-- comp.contract — Active contracts only
-- The filtered unique index from schema creation covers uniqueness.
-- This one serves lookup queries efficiently.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_contract_active
    ON comp.contract (team_id, end_date)
    INCLUDE (player_id, salary_monthly, currency, buyout_clause)
    WHERE status = 'Active';
GO

-- =============================================================================
-- comp.contract — Expiring contracts (within a rolling window)
-- SQL Server can't use a dynamic date in a filter, so we filter by status only
-- and let the query further filter by end_date range.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_contract_expiring
    ON comp.contract (end_date, player_id)
    INCLUDE (team_id, salary_monthly, currency)
    WHERE status = 'Active' AND end_date IS NOT NULL;
GO

-- =============================================================================
-- comp.match — Completed matches only
-- Standings, stats, and leaderboard queries only ever touch completed matches.
-- Scheduled and cancelled matches are dead weight for those queries.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_match_completed
    ON comp.match (tournament_id, played_at)
    INCLUDE (team_a_id, team_b_id, winner_id, score_a, score_b, stage, best_of)
    WHERE status = 'Completed';
GO

-- =============================================================================
-- comp.match — Live matches only
-- Broadcasting and real-time dashboards poll for live matches frequently.
-- This tiny filtered index makes that lookup near-instant.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_match_live
    ON comp.match (tournament_id, played_at)
    INCLUDE (team_a_id, team_b_id, score_a, score_b, stage)
    WHERE status = 'Live';
GO

-- =============================================================================
-- comp.tournament — Active/Ongoing tournaments
-- Dashboard and homepage queries for "current tournaments" are very frequent.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_tournament_active
    ON comp.tournament (league_id, start_date)
    INCLUDE (name, format, prize_pool, currency, end_date)
    WHERE status IN ('Scheduled', 'Ongoing');
GO

-- =============================================================================
-- comp.player_stat — MVP performances only
-- Used in "hall of fame" and "most MVPs" leaderboard queries.
-- Only a small fraction of rows have mvp_flag = 1.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_stat_mvp
    ON comp.player_stat (player_id, match_id)
    INCLUDE (kills, deaths, assists, damage_dealt)
    WHERE mvp_flag = 1
    ON FG_STATS;
GO

-- =============================================================================
-- comp.player_stat — First bloods only
-- "Who gets first blood most often" — tiny filtered index.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_stat_first_blood
    ON comp.player_stat (player_id)
    INCLUDE (match_id, kills, damage_dealt)
    WHERE first_blood = 1
    ON FG_STATS;
GO

-- =============================================================================
-- ops.ticket_order — Confirmed orders only
-- Revenue reports, seat count, and attendance figures exclude Cancelled/Refunded.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_order_confirmed
    ON ops.ticket_order (tier_id, ordered_at)
    INCLUDE (fan_id, quantity, total_amount, currency)
    WHERE status = 'Confirmed';
GO

-- =============================================================================
-- ops.ticket_tier — Tiers with available seats
-- Ticket purchase flows only query tiers where seats are still available.
-- seats_avail is a PERSISTED computed column (total_seats - seats_sold),
-- which allows it to be used in a filtered index WHERE clause.
-- SQL Server does not allow column-to-column comparisons in filtered index
-- predicates, so filtering on the persisted computed column is the correct pattern.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_tier_available
    ON ops.ticket_tier (event_id, price)
    INCLUDE (tier_name, total_seats, seats_sold, seats_avail, currency, sale_start, sale_end)
    WHERE seats_avail > 0;
GO

-- =============================================================================
-- ops.sponsorship — Active deals only
-- Sponsor dashboards, team pages, and revenue queries only show active deals.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_sponsorship_active
    ON ops.sponsorship (team_id, end_date)
    INCLUDE (sponsor_id, deal_value, currency, visibility_type)
    WHERE status = 'Active';
GO

-- =============================================================================
-- ops.broadcast_rights — Active rights only
-- Broadcast rights queries for live tournaments only need active agreements.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_rights_active
    ON ops.broadcast_rights (tournament_id, territory)
    INCLUDE (broadcaster_id, rights_type, fee, currency, end_date)
    WHERE status = 'Active';
GO

-- =============================================================================
-- ops.fan — Active fans only
-- Marketing and analytics queries typically exclude deactivated accounts.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_filter_fan_active
    ON ops.fan (country, registered_at)
    INCLUDE (fan_id, username, favourite_team_id, last_login)
    WHERE is_active = 1;
GO

-- =============================================================================
-- MONITORING: Check filtered index usage
-- Run periodically to confirm filtered indexes are being used,
-- not just maintained (wasted overhead if seek_count = 0).
-- =============================================================================

SELECT
    OBJECT_SCHEMA_NAME(i.object_id)     AS schema_name,
    OBJECT_NAME(i.object_id)            AS table_name,
    i.name                              AS index_name,
    i.filter_definition,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.last_user_seek,
    s.last_user_scan
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
    ON s.object_id  = i.object_id
    AND s.index_id  = i.index_id
    AND s.database_id = DB_ID()
WHERE i.has_filter = 1
  AND OBJECT_SCHEMA_NAME(i.object_id) IN ('comp','ops','audit')
ORDER BY s.user_seeks DESC;
GO

PRINT '04_filtered_indexes.sql: All filtered indexes created.';
GO
