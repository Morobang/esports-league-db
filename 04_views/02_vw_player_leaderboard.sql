-- =============================================================================
-- FILE:    02_vw_player_leaderboard.sql
-- PURPOSE: Player performance leaderboard across tournaments
--          Aggregates stats, ELO, MVP count, and first bloods per player
-- DEPENDS: 03_seed_data/ (all data seeded)
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.vw_player_leaderboard
-- One row per player per tournament.
-- Aggregates all player_stat rows for that tournament's matches.
-- Includes ELO rating snapshot and ranking within the tournament.
-- Used by: tournament pages, player profiles, hall of fame queries
-- =============================================================================

CREATE OR ALTER VIEW comp.vw_player_leaderboard
AS
WITH match_tournament AS (
    -- Bridge player_stat to tournament via match
    SELECT
        ps.stat_id,
        ps.match_id,
        ps.player_id,
        ps.kills,
        ps.deaths,
        ps.assists,
        ps.damage_dealt,
        ps.healing_done,
        ps.first_blood,
        ps.mvp_flag,
        m.tournament_id
    FROM comp.player_stat ps
    JOIN comp.match m ON m.match_id = ps.match_id
),
player_agg AS (
    -- Aggregate per player per tournament
    SELECT
        mt.player_id,
        mt.tournament_id,
        COUNT(DISTINCT mt.match_id)         AS matches_played,
        SUM(mt.kills)                        AS total_kills,
        SUM(mt.deaths)                       AS total_deaths,
        SUM(mt.assists)                      AS total_assists,
        SUM(mt.damage_dealt)                 AS total_damage,
        SUM(mt.healing_done)                 AS total_healing,
        SUM(CAST(mt.first_blood AS INT))     AS first_bloods,
        SUM(CAST(mt.mvp_flag AS INT))        AS mvp_count,
        -- KDA across all matches
        CASE
            WHEN SUM(mt.deaths) = 0
            THEN CAST(SUM(mt.kills) + SUM(mt.assists) AS DECIMAL(8,2))
            ELSE CAST(SUM(mt.kills) + SUM(mt.assists) AS DECIMAL(8,2))
                 / NULLIF(SUM(mt.deaths), 0)
        END                                  AS overall_kda,
        AVG(CAST(mt.damage_dealt AS DECIMAL(10,2))) AS avg_damage_per_match
    FROM match_tournament mt
    GROUP BY mt.player_id, mt.tournament_id
)
SELECT
    pa.player_id,
    pa.tournament_id,
    p.username,
    p.real_name,
    p.nationality,
    p.role,
    t.name                                  AS team_name,
    t.tag                                   AS team_tag,
    tn.name                                 AS tournament_name,
    g.name                                  AS game_name,
    pa.matches_played,
    pa.total_kills,
    pa.total_deaths,
    pa.total_assists,
    ROUND(pa.overall_kda, 2)                AS overall_kda,
    pa.total_damage,
    pa.total_healing,
    pa.first_bloods,
    pa.mvp_count,
    ROUND(pa.avg_damage_per_match, 0)       AS avg_damage_per_match,
    -- ELO rating for this tournament (if calculated)
    pr.elo_score,
    pr.rank_position                        AS elo_rank,
    pr.win_rate                             AS elo_win_rate,
    -- Leaderboard rank by total kills within each tournament
    RANK() OVER (
        PARTITION BY pa.tournament_id
        ORDER BY pa.total_kills DESC
    )                                       AS kills_rank,
    -- Leaderboard rank by KDA within each tournament
    RANK() OVER (
        PARTITION BY pa.tournament_id
        ORDER BY pa.overall_kda DESC
    )                                       AS kda_rank,
    -- Leaderboard rank by damage within each tournament
    RANK() OVER (
        PARTITION BY pa.tournament_id
        ORDER BY pa.total_damage DESC
    )                                       AS damage_rank
FROM player_agg pa
JOIN comp.player     p   ON p.player_id     = pa.player_id
JOIN comp.team       t   ON t.team_id       = p.team_id
JOIN comp.tournament tn  ON tn.tournament_id = pa.tournament_id
JOIN comp.league     l   ON l.league_id     = tn.league_id
JOIN comp.game       g   ON g.game_id       = l.game_id
LEFT JOIN comp.player_rating pr
    ON pr.player_id = pa.player_id
    AND pr.tournament_id = pa.tournament_id;
GO

-- Quick smoke test
-- SELECT * FROM comp.vw_player_leaderboard ORDER BY tournament_name, kills_rank;

PRINT '02_vw_player_leaderboard: view created.';
GO
