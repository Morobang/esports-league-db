-- =============================================================================
-- FILE:    01_vw_team_standings.sql
-- PURPOSE: Live league standings table with team details and map differential
-- DEPENDS: 03_seed_data/ (all data seeded)
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.vw_team_standings
-- Returns the full standings table for every league.
-- Includes rank position (window function), team tag, win rate, and map diff.
-- Used by: league pages, tournament seeding logic, usp_calculate_standings
-- =============================================================================

CREATE OR ALTER VIEW comp.vw_team_standings
AS
WITH standing_base AS (
    SELECT
        ts.standing_id,
        ts.league_id,
        ts.team_id,
        l.name                                          AS league_name,
        l.tier                                          AS league_tier,
        l.season,
        l.is_active                                     AS league_is_active,
        g.name                                          AS game_name,
        r.name                                          AS region_name,
        r.code                                          AS region_code,
        t.name                                          AS team_name,
        t.tag                                           AS team_tag,
        ts.wins,
        ts.losses,
        ts.draws,
        ts.points,
        ts.maps_won,
        ts.maps_lost,
        ts.maps_won - ts.maps_lost                      AS map_diff,
        ts.wins + ts.losses + ts.draws                  AS games_played,
        CASE
            WHEN ts.wins + ts.losses + ts.draws = 0 THEN 0.00
            ELSE CAST(ts.wins AS DECIMAL(5,2))
                 / (ts.wins + ts.losses + ts.draws) * 100
        END                                             AS win_rate_pct,
        ts.updated_at
    FROM comp.team_standing ts
    JOIN comp.league  l  ON l.league_id  = ts.league_id
    JOIN comp.game    g  ON g.game_id    = l.game_id
    JOIN comp.region  r  ON r.region_id  = l.region_id
    JOIN comp.team    t  ON t.team_id    = ts.team_id
)
SELECT
    standing_id,
    league_id,
    team_id,
    league_name,
    league_tier,
    season,
    league_is_active,
    game_name,
    region_name,
    region_code,
    team_name,
    team_tag,
    wins,
    losses,
    draws,
    points,
    maps_won,
    maps_lost,
    map_diff,
    games_played,
    ROUND(win_rate_pct, 1)                              AS win_rate_pct,
    -- Rank within each league by points, then map_diff as tiebreaker
    RANK() OVER (
        PARTITION BY league_id
        ORDER BY points DESC, map_diff DESC, wins DESC
    )                                                   AS league_rank,
    updated_at
FROM standing_base;
GO

-- Quick smoke test
-- SELECT * FROM comp.vw_team_standings ORDER BY league_name, league_rank;

PRINT '01_vw_team_standings: view created.';
GO
