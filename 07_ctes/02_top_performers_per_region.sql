-- =============================================================================
-- FILE:    02_top_performers_per_region.sql
-- PURPOSE: Multi-step CTE chains to identify top performers per region,
--          cross-region comparisons, and talent pipeline analysis
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- QUERY 1: Top performer per region per game — full CTE pipeline
--          Step 1: aggregate player stats per tournament
--          Step 2: join to region and game context
--          Step 3: rank within each region+game bucket
--          Step 4: filter to #1 per bucket and enrich with contract data
-- =============================================================================

WITH player_tournament_stats AS (
    -- Step 1: aggregate raw stats per player per tournament
    SELECT
        ps.player_id,
        m.tournament_id,
        COUNT(DISTINCT ps.match_id)                 AS matches_played,
        SUM(ps.kills)                               AS total_kills,
        SUM(ps.deaths)                              AS total_deaths,
        SUM(ps.assists)                             AS total_assists,
        SUM(ps.damage_dealt)                        AS total_damage,
        SUM(CAST(ps.mvp_flag AS INT))               AS mvp_count,
        CASE
            WHEN SUM(ps.deaths) = 0
            THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
            ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                 / NULLIF(SUM(ps.deaths), 0)
        END                                         AS kda_ratio
    FROM comp.player_stat ps
    JOIN comp.match       m ON m.match_id = ps.match_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id, m.tournament_id
),
enriched_stats AS (
    -- Step 2: join to player, team, region, game
    SELECT
        pts.player_id,
        pts.tournament_id,
        p.username,
        p.real_name,
        p.role,
        t.team_id,
        t.name                                      AS team_name,
        r.region_id,
        r.name                                      AS region_name,
        g.game_id,
        g.name                                      AS game_name,
        pts.matches_played,
        pts.total_kills,
        pts.total_deaths,
        pts.total_assists,
        pts.total_damage,
        pts.mvp_count,
        ROUND(pts.kda_ratio, 2)                     AS kda_ratio,
        -- Composite performance score: kills 40%, KDA 35%, damage 25%
        pts.total_kills * 0.40
            + pts.kda_ratio * 0.35 * 100
            + pts.total_damage / 1000.0 * 0.25      AS raw_perf_score
    FROM player_tournament_stats pts
    JOIN comp.player       p  ON p.player_id      = pts.player_id
    JOIN comp.team         t  ON t.team_id        = p.team_id
    JOIN comp.tournament   tn ON tn.tournament_id = pts.tournament_id
    JOIN comp.league       l  ON l.league_id      = tn.league_id
    JOIN comp.game         g  ON g.game_id        = l.game_id
    JOIN comp.region       r  ON r.region_id      = t.region_id
),
ranked_by_region AS (
    -- Step 3: rank within region+game
    SELECT
        *,
        RANK() OVER (
            PARTITION BY region_id, game_id
            ORDER BY raw_perf_score DESC
        )                                           AS region_game_rank,
        AVG(raw_perf_score) OVER (
            PARTITION BY region_id, game_id
        )                                           AS region_avg_score,
        MAX(raw_perf_score) OVER (
            PARTITION BY region_id, game_id
        )                                           AS region_best_score
    FROM enriched_stats
)
-- Step 4: top performer per region+game with contract context
SELECT
    rbr.region_name,
    rbr.game_name,
    rbr.region_game_rank,
    rbr.username,
    rbr.real_name,
    rbr.team_name,
    rbr.role,
    rbr.matches_played,
    rbr.total_kills,
    rbr.kda_ratio,
    rbr.total_damage,
    rbr.mvp_count,
    ROUND(rbr.raw_perf_score, 1)                    AS perf_score,
    ROUND(rbr.region_avg_score, 1)                  AS region_avg,
    ROUND(rbr.raw_perf_score - rbr.region_avg_score, 1)
                                                    AS above_region_avg,
    -- Contract details
    c.salary_monthly,
    c.currency,
    c.end_date                                      AS contract_ends,
    DATEDIFF(DAY, GETUTCDATE(), c.end_date)         AS days_to_expiry
FROM ranked_by_region  rbr
LEFT JOIN comp.contract c
    ON  c.player_id = rbr.player_id
    AND c.status    = 'Active'
WHERE rbr.region_game_rank <= 3    -- top 3 per region per game
ORDER BY rbr.region_name, rbr.game_name, rbr.region_game_rank;
GO

-- =============================================================================
-- QUERY 2: Cross-region talent comparison
--          Which region produces the highest average KDA?
--          Multi-step aggregation: player → team → region → comparison
-- =============================================================================

WITH player_career AS (
    SELECT
        ps.player_id,
        SUM(ps.kills)                               AS career_kills,
        SUM(ps.deaths)                              AS career_deaths,
        SUM(ps.assists)                             AS career_assists,
        SUM(ps.damage_dealt)                        AS career_damage,
        COUNT(DISTINCT ps.match_id)                 AS matches_played,
        CASE
            WHEN SUM(ps.deaths) = 0
            THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
            ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                 / NULLIF(SUM(ps.deaths), 0)
        END                                         AS career_kda
    FROM comp.player_stat ps
    JOIN comp.match       m ON m.match_id = ps.match_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id
),
player_region AS (
    SELECT
        pc.*,
        p.username,
        p.role,
        t.team_id,
        t.name                                      AS team_name,
        r.region_id,
        r.name                                      AS region_name
    FROM player_career  pc
    JOIN comp.player    p ON p.player_id = pc.player_id
    JOIN comp.team      t ON t.team_id   = p.team_id
    JOIN comp.region    r ON r.region_id = t.region_id
),
region_summary AS (
    SELECT
        region_id,
        region_name,
        COUNT(DISTINCT team_id)                     AS teams_in_region,
        COUNT(*)                                    AS total_players,
        ROUND(AVG(career_kda), 2)                   AS avg_kda,
        ROUND(AVG(CAST(career_kills AS FLOAT)), 1)  AS avg_kills,
        ROUND(AVG(CAST(career_damage AS FLOAT)), 0) AS avg_damage,
        MAX(career_kda)                             AS best_kda,
        SUM(matches_played)                         AS total_matches
    FROM player_region
    GROUP BY region_id, region_name
)
SELECT
    rs.region_name,
    rs.teams_in_region,
    rs.total_players,
    rs.avg_kda,
    rs.avg_kills,
    rs.avg_damage,
    rs.best_kda,
    rs.total_matches,
    -- Global rank by average KDA
    RANK() OVER (ORDER BY rs.avg_kda DESC)          AS global_kda_rank,
    -- Top player in this region
    (
        SELECT TOP 1 pr2.username
        FROM player_region pr2
        WHERE pr2.region_id = rs.region_id
        ORDER BY pr2.career_kda DESC
    )                                               AS top_player,
    (
        SELECT TOP 1 ROUND(pr2.career_kda, 2)
        FROM player_region pr2
        WHERE pr2.region_id = rs.region_id
        ORDER BY pr2.career_kda DESC
    )                                               AS top_player_kda
FROM region_summary rs
ORDER BY rs.avg_kda DESC;
GO

-- =============================================================================
-- QUERY 3: Roster churn analysis — which teams have had the most player movement?
--          Uses CTEs to separate current vs historical contracts,
--          then computes turnover rate per team
-- =============================================================================

WITH active_contracts AS (
    SELECT
        team_id,
        player_id,
        salary_monthly,
        start_date,
        end_date
    FROM comp.contract
    WHERE status = 'Active'
),
expired_contracts AS (
    SELECT
        team_id,
        player_id,
        salary_monthly,
        start_date,
        end_date,
        DATEDIFF(MONTH, start_date, end_date)       AS contract_months
    FROM comp.contract
    WHERE status IN ('Expired', 'Terminated')
),
team_roster_stats AS (
    SELECT
        t.team_id,
        t.name                                      AS team_name,
        r.name                                      AS region_name,
        -- Current roster size
        COUNT(DISTINCT ac.player_id)                AS current_roster_size,
        -- Average current salary
        ROUND(AVG(ac.salary_monthly), 0)            AS avg_current_salary,
        -- Total salary commitment
        SUM(ac.salary_monthly)                      AS monthly_wage_bill
    FROM comp.team      t
    JOIN comp.region    r  ON r.region_id = t.region_id
    LEFT JOIN active_contracts ac ON ac.team_id = t.team_id
    WHERE t.is_active = 1
    GROUP BY t.team_id, t.name, r.name
),
team_turnover AS (
    SELECT
        ec.team_id,
        COUNT(DISTINCT ec.player_id)                AS players_departed,
        ROUND(AVG(CAST(ec.contract_months AS FLOAT)), 1)
                                                    AS avg_contract_length_months,
        SUM(ec.salary_monthly)                      AS total_departed_salary
    FROM expired_contracts ec
    GROUP BY ec.team_id
)
SELECT
    trs.team_name,
    trs.region_name,
    trs.current_roster_size,
    trs.avg_current_salary,
    trs.monthly_wage_bill,
    COALESCE(tt.players_departed, 0)                AS players_departed,
    COALESCE(tt.avg_contract_length_months, 0)      AS avg_contract_months,
    -- Turnover rate: departed / (current + departed)
    ROUND(
        100.0 * COALESCE(tt.players_departed, 0)
        / NULLIF(trs.current_roster_size + COALESCE(tt.players_departed, 0), 0),
    1)                                              AS turnover_rate_pct,
    -- Salary inflation: current avg vs avg of departed contracts
    ROUND(
        trs.avg_current_salary
        - COALESCE(tt.total_departed_salary, 0)
          / NULLIF(tt.players_departed, 0),
    0)                                              AS salary_delta_vs_departed
FROM team_roster_stats trs
LEFT JOIN team_turnover tt ON tt.team_id = trs.team_id
ORDER BY turnover_rate_pct DESC, trs.monthly_wage_bill DESC;
GO

PRINT '02_top_performers_per_region.sql loaded.';
GO
