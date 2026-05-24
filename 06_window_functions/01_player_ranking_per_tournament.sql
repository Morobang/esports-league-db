-- =============================================================================
-- FILE:    01_player_ranking_per_tournament.sql
-- PURPOSE: Demonstrate RANK, DENSE_RANK, ROW_NUMBER, and NTILE window functions
--          for player leaderboards within each tournament
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- QUERY 1: RANK vs DENSE_RANK vs ROW_NUMBER — understanding the difference
--
-- RANK       → leaves gaps after ties  (1, 2, 2, 4)
-- DENSE_RANK → no gaps after ties      (1, 2, 2, 3)
-- ROW_NUMBER → no ties at all          (1, 2, 3, 4) — arbitrary tiebreak
-- =============================================================================

SELECT
    p.username,
    tn.name                                         AS tournament_name,
    SUM(ps.kills)                                   AS total_kills,
    SUM(ps.damage_dealt)                            AS total_damage,

    -- Three ranking approaches on the same partition
    RANK() OVER (
        PARTITION BY m.tournament_id
        ORDER BY SUM(ps.kills) DESC
    )                                               AS rank_kills,

    DENSE_RANK() OVER (
        PARTITION BY m.tournament_id
        ORDER BY SUM(ps.kills) DESC
    )                                               AS dense_rank_kills,

    ROW_NUMBER() OVER (
        PARTITION BY m.tournament_id
        ORDER BY SUM(ps.kills) DESC, SUM(ps.damage_dealt) DESC
    )                                               AS row_num_kills

FROM comp.player_stat  ps
JOIN comp.match        m   ON m.match_id       = ps.match_id
JOIN comp.tournament   tn  ON tn.tournament_id = m.tournament_id
JOIN comp.player       p   ON p.player_id      = ps.player_id
WHERE m.status = 'Completed'
GROUP BY ps.player_id, p.username, m.tournament_id, tn.name
ORDER BY tn.name, rank_kills;
GO

-- =============================================================================
-- QUERY 2: TOP 3 players per tournament by KDA (no CROSS APPLY needed)
--          Uses ROW_NUMBER to filter to top N per partition
-- =============================================================================

WITH player_kda AS (
    SELECT
        ps.player_id,
        p.username,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        SUM(ps.kills)                               AS total_kills,
        SUM(ps.deaths)                              AS total_deaths,
        SUM(ps.assists)                             AS total_assists,
        CASE
            WHEN SUM(ps.deaths) = 0
            THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS DECIMAL(8,2))
            ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS DECIMAL(8,2))
                 / NULLIF(SUM(ps.deaths), 0)
        END                                         AS kda_ratio
    FROM comp.player_stat  ps
    JOIN comp.match        m  ON m.match_id       = ps.match_id
    JOIN comp.tournament   tn ON tn.tournament_id = m.tournament_id
    JOIN comp.player       p  ON p.player_id      = ps.player_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id, p.username, m.tournament_id, tn.name
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY tournament_id
            ORDER BY kda_ratio DESC, total_kills DESC
        )                                           AS kda_rank
    FROM player_kda
)
SELECT
    tournament_name,
    kda_rank,
    username,
    total_kills,
    total_deaths,
    total_assists,
    ROUND(kda_ratio, 2)                             AS kda_ratio
FROM ranked
WHERE kda_rank <= 3
ORDER BY tournament_name, kda_rank;
GO

-- =============================================================================
-- QUERY 3: NTILE — split players into performance quartiles per tournament
--          Useful for tiering players into Bronze / Silver / Gold / Elite
-- =============================================================================

WITH player_damage AS (
    SELECT
        ps.player_id,
        p.username,
        t.name                                      AS team_name,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        SUM(ps.damage_dealt)                        AS total_damage,
        SUM(CAST(ps.mvp_flag AS INT))               AS mvp_count
    FROM comp.player_stat  ps
    JOIN comp.match        m   ON m.match_id       = ps.match_id
    JOIN comp.tournament   tn  ON tn.tournament_id = m.tournament_id
    JOIN comp.player       p   ON p.player_id      = ps.player_id
    JOIN comp.team         t   ON t.team_id        = p.team_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id, p.username, t.name, m.tournament_id, tn.name
)
SELECT
    tournament_name,
    username,
    team_name,
    total_damage,
    mvp_count,
    NTILE(4) OVER (
        PARTITION BY tournament_id
        ORDER BY total_damage DESC
    )                                               AS damage_quartile,
    CASE NTILE(4) OVER (
            PARTITION BY tournament_id
            ORDER BY total_damage DESC
         )
        WHEN 1 THEN 'Elite'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Silver'
        WHEN 4 THEN 'Bronze'
    END                                             AS performance_tier
FROM player_damage
ORDER BY tournament_name, damage_quartile, total_damage DESC;
GO

-- =============================================================================
-- QUERY 4: PERCENT_RANK and CUME_DIST — where does a player sit in the field?
--
-- PERCENT_RANK → relative rank as a 0–1 value  (0 = best, 1 = worst)
-- CUME_DIST    → what fraction of players scored <= this player's damage
-- =============================================================================

WITH player_totals AS (
    SELECT
        ps.player_id,
        p.username,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        SUM(ps.kills)                               AS total_kills,
        SUM(ps.damage_dealt)                        AS total_damage
    FROM comp.player_stat  ps
    JOIN comp.match        m  ON m.match_id       = ps.match_id
    JOIN comp.tournament   tn ON tn.tournament_id = m.tournament_id
    JOIN comp.player       p  ON p.player_id      = ps.player_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id, p.username, m.tournament_id, tn.name
)
SELECT
    tournament_name,
    username,
    total_kills,
    total_damage,

    ROUND(PERCENT_RANK() OVER (
        PARTITION BY tournament_id
        ORDER BY total_damage DESC
    ) * 100, 1)                                     AS pct_rank_damage,

    ROUND(CUME_DIST() OVER (
        PARTITION BY tournament_id
        ORDER BY total_damage
    ) * 100, 1)                                     AS cume_dist_damage

FROM player_totals
ORDER BY tournament_name, total_damage DESC;
GO

PRINT '01_player_ranking_per_tournament.sql loaded.';
GO
