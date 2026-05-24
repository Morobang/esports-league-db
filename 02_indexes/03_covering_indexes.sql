-- =============================================================================
-- FILE:    03_covering_indexes.sql
-- PURPOSE: Covering indexes that satisfy entire queries without key lookups.
--          Each index is tied to a named query pattern it serves.
--          Run AFTER 02_nonclustered_indexes.sql.
-- =============================================================================
--
-- A COVERING INDEX includes all columns a query needs in the index itself,
-- so SQL Server never has to go back to the clustered index (no key lookup).
-- The cost of a key lookup is roughly 3–5x the cost of the index seek.
-- For hot queries executed thousands of times, this matters.
--
-- Pattern: CREATE NONCLUSTERED INDEX IX_cover_<query_label>
--              ON <table> (<seek columns>)
--              INCLUDE (<non-seek columns the query selects>);
--
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- QUERY: Tournament leaderboard
-- "Get all players ranked by ELO in a given tournament"
--
-- SELECT p.username, pr.elo_score, pr.rank_position, pr.games_played, pr.win_rate
-- FROM comp.player_rating pr
-- JOIN comp.player p ON p.player_id = pr.player_id
-- WHERE pr.tournament_id = @tid
-- ORDER BY pr.elo_score DESC
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_leaderboard
    ON comp.player_rating (tournament_id, elo_score DESC)
    INCLUDE (player_id, rank_position, games_played, win_rate, calculated_at);
GO
-- Note: player.username still needs a join — this covers the player_rating side fully.

-- =============================================================================
-- QUERY: Active roster per team
-- "Show all active players for team X with role and join date"
--
-- SELECT username, real_name, nationality, role, joined_at
-- FROM comp.player
-- WHERE team_id = @tid AND status = 'Active'
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_active_roster
    ON comp.player (team_id, status)
    INCLUDE (username, real_name, nationality, role, joined_at);
GO

-- =============================================================================
-- QUERY: Contract expiry dashboard
-- "Find all active contracts expiring within 90 days"
--
-- SELECT c.contract_id, p.username, t.name, c.salary_monthly, c.end_date
-- FROM comp.contract c
-- JOIN comp.player p ON p.player_id = c.player_id
-- JOIN comp.team   t ON t.team_id   = c.team_id
-- WHERE c.status = 'Active'
--   AND c.end_date BETWEEN GETDATE() AND DATEADD(DAY, 90, GETDATE())
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_contract_expiry
    ON comp.contract (status, end_date)
    INCLUDE (player_id, team_id, salary_monthly, currency, buyout_clause);
GO

-- =============================================================================
-- QUERY: Match results for a tournament stage
-- "Get all completed match results for the quarter-final stage"
--
-- SELECT match_id, team_a_id, team_b_id, winner_id, score_a, score_b, played_at
-- FROM comp.match
-- WHERE tournament_id = @tid AND stage = @stage AND status = 'Completed'
-- ORDER BY played_at
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_match_stage
    ON comp.match (tournament_id, stage, status)
    INCLUDE (team_a_id, team_b_id, winner_id, score_a, score_b, best_of, played_at);
GO

-- =============================================================================
-- QUERY: Player performance summary per match
-- "Get all stats for players in a specific match"
--
-- SELECT ps.player_id, ps.kills, ps.deaths, ps.assists,
--        ps.kda_ratio, ps.damage_dealt, ps.mvp_flag
-- FROM comp.player_stat ps
-- WHERE ps.match_id = @mid
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_stat_by_match
    ON comp.player_stat (match_id)
    INCLUDE (player_id, kills, deaths, assists, damage_dealt, healing_done, first_blood, mvp_flag)
    ON FG_STATS;
GO

-- =============================================================================
-- QUERY: Top MVP players across a tournament
-- "Find players with the most MVP flags in tournament X"
--
-- SELECT ps.player_id, COUNT(*) AS mvp_count
-- FROM comp.player_stat ps
-- JOIN comp.match m ON m.match_id = ps.match_id
-- WHERE m.tournament_id = @tid AND ps.mvp_flag = 1
-- GROUP BY ps.player_id
-- ORDER BY mvp_count DESC
-- =============================================================================
-- match.tournament_id is covered by IX_match_tournament_id (file 02)
-- player_stat needs mvp_flag as seek-level filter

CREATE NONCLUSTERED INDEX IX_cover_mvp_flag
    ON comp.player_stat (mvp_flag, match_id)
    INCLUDE (player_id, kills, deaths, assists, damage_dealt)
    ON FG_STATS;
GO

-- =============================================================================
-- QUERY: Ticket revenue per event
-- "Total revenue by ticket tier for a given event"
--
-- SELECT tt.tier_name, tt.price, SUM(o.quantity) AS tickets_sold,
--        SUM(o.total_amount) AS revenue
-- FROM ops.ticket_order o
-- JOIN ops.ticket_tier tt ON tt.tier_id = o.tier_id
-- WHERE tt.event_id = @eid AND o.status = 'Confirmed'
-- GROUP BY tt.tier_name, tt.price
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_order_revenue
    ON ops.ticket_order (tier_id, status)
    INCLUDE (fan_id, quantity, total_amount, ordered_at);
GO

CREATE NONCLUSTERED INDEX IX_cover_tier_event
    ON ops.ticket_tier (event_id)
    INCLUDE (tier_id, tier_name, price, currency, total_seats, seats_sold);
GO

-- =============================================================================
-- QUERY: Sponsor ROI summary
-- "Total sponsorship deal value by sponsor tier and visibility type"
--
-- SELECT s.tier, sp.visibility_type, SUM(sp.deal_value) AS total_value
-- FROM ops.sponsorship sp
-- JOIN ops.sponsor s ON s.sponsor_id = sp.sponsor_id
-- WHERE sp.status = 'Active'
-- GROUP BY s.tier, sp.visibility_type
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_sponsorship_active
    ON ops.sponsorship (status, sponsor_id)
    INCLUDE (team_id, tournament_id, deal_value, visibility_type, currency);
GO

-- =============================================================================
-- QUERY: Peak viewership per tournament
-- "Get peak and average viewers for every match in a tournament"
--
-- SELECT m.match_id, m.stage, vl.peak_viewers, vl.avg_viewers, vl.logged_at
-- FROM ops.viewership_log vl
-- JOIN comp.match m ON m.match_id = vl.match_id
-- WHERE m.tournament_id = @tid
-- ORDER BY vl.peak_viewers DESC
-- =============================================================================
-- comp.match is covered by IX_match_tournament_id (file 02)
-- viewership_log needs a cover on match_id

CREATE NONCLUSTERED INDEX IX_cover_vlog_peak
    ON ops.viewership_log (match_id, peak_viewers DESC)
    INCLUDE (rights_id, avg_viewers, stream_duration_min, chat_messages, logged_at)
    ON FG_LOGS;
GO

-- =============================================================================
-- QUERY: League standings table (the single most queried view)
-- "Get full standings for league X sorted by points, then map_diff"
--
-- SELECT ts.team_id, t.name, t.tag,
--        ts.wins, ts.losses, ts.points, ts.map_diff
-- FROM comp.team_standing ts
-- JOIN comp.team t ON t.team_id = ts.team_id
-- WHERE ts.league_id = @lid
-- ORDER BY ts.points DESC, ts.map_diff DESC
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_cover_standings
    ON comp.team_standing (league_id, points DESC)
    INCLUDE (team_id, wins, losses, draws, maps_won, maps_lost, updated_at);
GO
-- Note: map_diff is a computed column — not includable; computed at read time.

PRINT '03_covering_indexes.sql: All covering indexes created.';
GO
