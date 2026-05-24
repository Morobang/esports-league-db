-- =============================================================================
-- FILE:    02_nonclustered_indexes.sql
-- PURPOSE: Non-clustered indexes on high-frequency join, filter, and sort columns
-- DEPENDS: 01_schema/ (all tables must exist)
-- RUN:     After all schema files. Before seed data.
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.league
-- Common queries: filter by game, region, season, active status
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_league_game_id
    ON comp.league (game_id)
    INCLUDE (name, tier, season, start_date, end_date, is_active);
GO

CREATE NONCLUSTERED INDEX IX_league_region_season
    ON comp.league (region_id, season)
    INCLUDE (game_id, name, tier, is_active);
GO

-- =============================================================================
-- comp.team
-- Common queries: lookup by region, active teams
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_team_region_active
    ON comp.team (region_id, is_active)
    INCLUDE (name, tag, founded_at);
GO

-- =============================================================================
-- comp.player
-- Common queries: all players on a team, free agents, by status
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_player_team_id
    ON comp.player (team_id)
    INCLUDE (username, role, status, joined_at, left_at);
GO

CREATE NONCLUSTERED INDEX IX_player_status
    ON comp.player (status)
    INCLUDE (team_id, username, nationality, role);
GO

-- =============================================================================
-- comp.staff
-- Common queries: all staff on a team, by role
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_staff_team_id
    ON comp.staff (team_id)
    INCLUDE (full_name, role, joined_at, left_at);
GO

-- =============================================================================
-- comp.contract
-- Common queries: active contracts by team, salary range queries,
--                 contracts expiring soon (date range scans)
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_contract_player_id
    ON comp.contract (player_id)
    INCLUDE (team_id, salary_monthly, currency, start_date, end_date, status);
GO

CREATE NONCLUSTERED INDEX IX_contract_team_status
    ON comp.contract (team_id, status)
    INCLUDE (player_id, salary_monthly, end_date);
GO

CREATE NONCLUSTERED INDEX IX_contract_end_date
    ON comp.contract (end_date)
    INCLUDE (player_id, team_id, status, salary_monthly);
GO

-- =============================================================================
-- comp.tournament
-- Common queries: tournaments by league, status, date range
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_tournament_league_id
    ON comp.tournament (league_id)
    INCLUDE (name, format, prize_pool, start_date, end_date, status);
GO

CREATE NONCLUSTERED INDEX IX_tournament_status_dates
    ON comp.tournament (status, start_date, end_date)
    INCLUDE (league_id, name, prize_pool);
GO

-- =============================================================================
-- comp.tournament_team
-- Common queries: all teams in a tournament, all tournaments for a team
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_tt_team_id
    ON comp.tournament_team (team_id)
    INCLUDE (tournament_id, seed, final_placement, is_eliminated);
GO

-- =============================================================================
-- comp.match
-- One of the hottest tables — drives standings, stats, leaderboards
-- Common queries:
--   - All matches in a tournament
--   - All matches for a team (as team_a OR team_b)
--   - Completed matches in date range
--   - Matches by stage
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_match_tournament_id
    ON comp.match (tournament_id)
    INCLUDE (team_a_id, team_b_id, winner_id, score_a, score_b, stage, played_at, status);
GO

CREATE NONCLUSTERED INDEX IX_match_team_a
    ON comp.match (team_a_id)
    INCLUDE (tournament_id, team_b_id, winner_id, score_a, score_b, played_at, status);
GO

CREATE NONCLUSTERED INDEX IX_match_team_b
    ON comp.match (team_b_id)
    INCLUDE (tournament_id, team_a_id, winner_id, score_a, score_b, played_at, status);
GO

CREATE NONCLUSTERED INDEX IX_match_played_at
    ON comp.match (played_at)
    INCLUDE (tournament_id, winner_id, stage, status);
GO

-- =============================================================================
-- comp.match_map
-- Common queries: all maps for a match, ordered by map_number
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_match_map_match_id
    ON comp.match_map (match_id, map_number)
    INCLUDE (map_name, team_a_score, team_b_score, duration_min);
GO

-- =============================================================================
-- comp.player_stat  (on FG_STATS)
-- Common queries: stats by player, stats by match, top performers
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_pstat_player_id
    ON comp.player_stat (player_id)
    INCLUDE (match_id, kills, deaths, assists, damage_dealt, mvp_flag)
    ON FG_STATS;
GO

CREATE NONCLUSTERED INDEX IX_pstat_match_id
    ON comp.player_stat (match_id)
    INCLUDE (player_id, kills, deaths, assists, damage_dealt, healing_done, mvp_flag)
    ON FG_STATS;
GO

-- =============================================================================
-- comp.player_rating  (on FG_STATS)
-- Common queries: leaderboard per tournament, player rating history
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_prating_tournament_elo
    ON comp.player_rating (tournament_id, elo_score DESC)
    INCLUDE (player_id, rank_position, games_played, win_rate, calculated_at)
    ON FG_STATS;
GO

CREATE NONCLUSTERED INDEX IX_prating_player_id
    ON comp.player_rating (player_id)
    INCLUDE (tournament_id, elo_score, rank_position, calculated_at)
    ON FG_STATS;
GO

-- =============================================================================
-- comp.team_standing
-- Common queries: standings table for a league (sorted by points DESC)
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_standing_league_points
    ON comp.team_standing (league_id, points DESC)
    INCLUDE (team_id, wins, losses, draws, maps_won, maps_lost, updated_at);
GO

-- =============================================================================
-- ops.event
-- Common queries: events by tournament, upcoming events by date
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_event_tournament_id
    ON ops.event (tournament_id)
    INCLUDE (venue_id, name, event_type, start_datetime, end_datetime, status);
GO

CREATE NONCLUSTERED INDEX IX_event_start_datetime
    ON ops.event (start_datetime)
    INCLUDE (tournament_id, venue_id, event_type, status);
GO

-- =============================================================================
-- ops.ticket_tier
-- Common queries: all tiers for an event, available seats
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_tier_event_id
    ON ops.ticket_tier (event_id)
    INCLUDE (tier_name, price, currency, total_seats, seats_sold);
GO

-- =============================================================================
-- ops.fan
-- Common queries: lookup by email, by country, by favourite team
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_fan_country
    ON ops.fan (country)
    INCLUDE (fan_id, username, favourite_team_id, registered_at, is_active);
GO

CREATE NONCLUSTERED INDEX IX_fan_favourite_team
    ON ops.fan (favourite_team_id)
    INCLUDE (fan_id, username, country, registered_at);
GO

-- =============================================================================
-- ops.ticket_order
-- Common queries: orders by fan, orders by tier, revenue by date
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_order_fan_id
    ON ops.ticket_order (fan_id)
    INCLUDE (tier_id, quantity, total_amount, status, ordered_at);
GO

CREATE NONCLUSTERED INDEX IX_order_tier_id
    ON ops.ticket_order (tier_id)
    INCLUDE (fan_id, quantity, total_amount, status, ordered_at);
GO

CREATE NONCLUSTERED INDEX IX_order_ordered_at
    ON ops.ticket_order (ordered_at)
    INCLUDE (fan_id, tier_id, total_amount, status);
GO

-- =============================================================================
-- ops.sponsorship
-- Common queries: all deals for a sponsor, all deals for a team/tournament
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_sponsorship_sponsor_id
    ON ops.sponsorship (sponsor_id)
    INCLUDE (team_id, tournament_id, deal_value, start_date, end_date, status);
GO

CREATE NONCLUSTERED INDEX IX_sponsorship_team_id
    ON ops.sponsorship (team_id)
    INCLUDE (sponsor_id, tournament_id, deal_value, visibility_type, status);
GO

CREATE NONCLUSTERED INDEX IX_sponsorship_tournament_id
    ON ops.sponsorship (tournament_id)
    INCLUDE (sponsor_id, team_id, deal_value, visibility_type, status);
GO

-- =============================================================================
-- ops.broadcast_rights
-- Common queries: rights by tournament, active rights by broadcaster
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_rights_tournament_id
    ON ops.broadcast_rights (tournament_id)
    INCLUDE (broadcaster_id, rights_type, territory, fee, status);
GO

CREATE NONCLUSTERED INDEX IX_rights_broadcaster_id
    ON ops.broadcast_rights (broadcaster_id)
    INCLUDE (tournament_id, rights_type, territory, start_date, end_date, status);
GO

-- =============================================================================
-- ops.viewership_log  (on FG_LOGS)
-- Common queries: peak viewers by match, total views by tournament,
--                 time-range aggregations
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_vlog_match_id
    ON ops.viewership_log (match_id)
    INCLUDE (rights_id, peak_viewers, avg_viewers, logged_at)
    ON FG_LOGS;
GO

CREATE NONCLUSTERED INDEX IX_vlog_rights_id
    ON ops.viewership_log (rights_id)
    INCLUDE (match_id, peak_viewers, avg_viewers, stream_duration_min, logged_at)
    ON FG_LOGS;
GO

-- =============================================================================
-- audit.log  (on FG_LOGS)
-- Common queries: audit trail by table, by user, by date range
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_audit_table_operation
    ON audit.log (schema_name, table_name, operation)
    INCLUDE (record_id, changed_by, changed_at)
    ON FG_LOGS;
GO

CREATE NONCLUSTERED INDEX IX_audit_changed_by
    ON audit.log (changed_by, changed_at)
    INCLUDE (schema_name, table_name, operation, record_id)
    ON FG_LOGS;
GO

PRINT '02_nonclustered_indexes.sql: All non-clustered indexes created.';
GO
