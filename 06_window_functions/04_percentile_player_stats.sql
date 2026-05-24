-- =============================================================================
-- FILE:    04_percentile_player_stats.sql
-- PURPOSE: PERCENTILE_CONT, PERCENTILE_DISC, statistical aggregates,
--          and outlier detection for player performance data
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- QUERY 1: PERCENTILE_CONT — median and distribution of player damage
--
-- PERCENTILE_CONT(0.5) → median (interpolated between two middle values)
-- PERCENTILE_DISC(0.5) → median (returns an actual value that exists in data)
-- PERCENTILE_CONT(0.9) → 90th percentile threshold
-- =============================================================================

WITH player_totals AS (
    SELECT
        ps.player_id,
        p.username,
        t.name                                      AS team_name,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        SUM(ps.damage_dealt)                        AS total_damage,
        SUM(ps.kills)                               AS total_kills,
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
    JOIN comp.team         t  ON t.team_id        = p.team_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id, p.username, t.name, m.tournament_id, tn.name
)
SELECT
    tournament_name,
    username,
    team_name,
    total_damage,
    total_kills,
    ROUND(kda_ratio, 2)                             AS kda_ratio,

    -- Median damage in this tournament
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_damage)
        OVER (PARTITION BY tournament_id)           AS median_damage,

    -- Actual median value that exists in the data
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY total_damage)
        OVER (PARTITION BY tournament_id)           AS median_damage_disc,

    -- 75th and 90th percentile thresholds
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_damage)
        OVER (PARTITION BY tournament_id)           AS p75_damage,

    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_damage)
        OVER (PARTITION BY tournament_id)           AS p90_damage,

    -- Is this player above the 75th percentile?
    CASE
        WHEN total_damage > PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_damage)
            OVER (PARTITION BY tournament_id)
        THEN 'Above P75'
        WHEN total_damage > PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_damage)
            OVER (PARTITION BY tournament_id)
        THEN 'Above Median'
        ELSE 'Below Median'
    END                                             AS damage_tier

FROM player_totals
ORDER BY tournament_name, total_damage DESC;
GO

-- =============================================================================
-- QUERY 2: Z-score outlier detection — find statistically exceptional performers
--
-- Z-score = (value - mean) / stddev
-- Z > 2.0 → significantly above average (top ~2.3%)
-- Z < -2.0 → significantly below average
-- =============================================================================

WITH player_match_damage AS (
    SELECT
        ps.player_id,
        p.username,
        ps.match_id,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        ps.damage_dealt,
        ps.kills,
        ps.mvp_flag
    FROM comp.player_stat  ps
    JOIN comp.match        m  ON m.match_id       = ps.match_id
    JOIN comp.tournament   tn ON tn.tournament_id = m.tournament_id
    JOIN comp.player       p  ON p.player_id      = ps.player_id
    WHERE m.status = 'Completed'
),
with_stats AS (
    SELECT
        *,
        AVG(CAST(damage_dealt AS FLOAT)) OVER (
            PARTITION BY tournament_id
        )                                           AS mean_damage,
        STDEV(CAST(damage_dealt AS FLOAT)) OVER (
            PARTITION BY tournament_id
        )                                           AS stddev_damage
    FROM player_match_damage
)
SELECT
    tournament_name,
    username,
    match_id,
    damage_dealt,
    ROUND(mean_damage, 0)                           AS tournament_mean_damage,
    ROUND(stddev_damage, 0)                         AS tournament_stddev,
    ROUND(
        (damage_dealt - mean_damage) / NULLIF(stddev_damage, 0),
    2)                                              AS z_score,
    CASE
        WHEN (damage_dealt - mean_damage) / NULLIF(stddev_damage, 0) > 2.0
        THEN 'Exceptional'
        WHEN (damage_dealt - mean_damage) / NULLIF(stddev_damage, 0) > 1.0
        THEN 'Strong'
        WHEN (damage_dealt - mean_damage) / NULLIF(stddev_damage, 0) < -1.0
        THEN 'Weak'
        ELSE 'Normal'
    END                                             AS performance_flag,
    mvp_flag
FROM with_stats
ORDER BY tournament_name, z_score DESC;
GO

-- =============================================================================
-- QUERY 3: Contract salary percentile distribution
--          Where does each player's salary rank within their team's region?
-- =============================================================================

WITH active_contracts AS (
    SELECT
        c.contract_id,
        c.player_id,
        p.username,
        p.role,
        t.name                                      AS team_name,
        r.name                                      AS region_name,
        c.salary_monthly,
        c.end_date,
        DATEDIFF(DAY, GETUTCDATE(), c.end_date)     AS days_to_expiry
    FROM comp.contract c
    JOIN comp.player   p ON p.player_id = c.player_id
    JOIN comp.team     t ON t.team_id   = c.team_id
    JOIN comp.region   r ON r.region_id = t.region_id
    WHERE c.status = 'Active'
)
SELECT
    username,
    team_name,
    region_name,
    role,
    salary_monthly,
    days_to_expiry,

    -- Salary rank within region (1 = highest paid)
    RANK() OVER (
        PARTITION BY region_name
        ORDER BY salary_monthly DESC
    )                                               AS salary_rank_in_region,

    -- Percentile within region
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY region_name
        ORDER BY salary_monthly
    ) * 100, 1)                                     AS salary_pct_rank,

    -- Regional salary benchmarks
    ROUND(AVG(salary_monthly) OVER (
        PARTITION BY region_name
    ), 2)                                           AS regional_avg_salary,

    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_monthly)
        OVER (PARTITION BY region_name)             AS regional_median_salary,

    -- Is this player above or below regional median?
    CASE
        WHEN salary_monthly > PERCENTILE_CONT(0.5) WITHIN GROUP
            (ORDER BY salary_monthly) OVER (PARTITION BY region_name)
        THEN 'Above Median'
        ELSE 'At or Below Median'
    END                                             AS vs_regional_median,

    -- How much above/below the regional average?
    ROUND(salary_monthly - AVG(salary_monthly) OVER (PARTITION BY region_name), 2)
                                                    AS delta_from_avg

FROM active_contracts
ORDER BY region_name, salary_rank_in_region;
GO

-- =============================================================================
-- QUERY 4: Combined performance score (composite ranking)
--          Weight kills (40%), KDA (35%), damage (25%) into one score
--          then rank players globally across all tournaments
-- =============================================================================

WITH player_totals AS (
    SELECT
        ps.player_id,
        p.username,
        t.name                                      AS team_name,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        SUM(ps.kills)                               AS total_kills,
        SUM(ps.deaths)                              AS total_deaths,
        SUM(ps.assists)                             AS total_assists,
        SUM(ps.damage_dealt)                        AS total_damage,
        CASE
            WHEN SUM(ps.deaths) = 0
            THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
            ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                 / NULLIF(SUM(ps.deaths), 0)
        END                                         AS kda_ratio
    FROM comp.player_stat  ps
    JOIN comp.match        m  ON m.match_id       = ps.match_id
    JOIN comp.tournament   tn ON tn.tournament_id = m.tournament_id
    JOIN comp.player       p  ON p.player_id      = ps.player_id
    JOIN comp.team         t  ON t.team_id        = p.team_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id, p.username, t.name, m.tournament_id, tn.name
),
normalised AS (
    -- Min-max normalise each metric to 0-100 within each tournament
    SELECT
        *,
        100.0 * (total_kills - MIN(total_kills) OVER (PARTITION BY tournament_id))
            / NULLIF(MAX(total_kills) OVER (PARTITION BY tournament_id)
                   - MIN(total_kills) OVER (PARTITION BY tournament_id), 0)
                                                    AS kills_score,
        100.0 * (kda_ratio - MIN(kda_ratio) OVER (PARTITION BY tournament_id))
            / NULLIF(MAX(kda_ratio) OVER (PARTITION BY tournament_id)
                   - MIN(kda_ratio) OVER (PARTITION BY tournament_id), 0)
                                                    AS kda_score,
        100.0 * (total_damage - MIN(total_damage) OVER (PARTITION BY tournament_id))
            / NULLIF(MAX(total_damage) OVER (PARTITION BY tournament_id)
                   - MIN(total_damage) OVER (PARTITION BY tournament_id), 0)
                                                    AS damage_score
    FROM player_totals
)
SELECT
    tournament_name,
    username,
    team_name,
    total_kills,
    ROUND(kda_ratio, 2)                             AS kda_ratio,
    total_damage,
    -- Weighted composite score
    ROUND(
        0.40 * COALESCE(kills_score, 0)
      + 0.35 * COALESCE(kda_score, 0)
      + 0.25 * COALESCE(damage_score, 0),
    1)                                              AS composite_score,
    -- Rank by composite score within each tournament
    RANK() OVER (
        PARTITION BY tournament_id
        ORDER BY (
            0.40 * COALESCE(kills_score, 0)
          + 0.35 * COALESCE(kda_score, 0)
          + 0.25 * COALESCE(damage_score, 0)
        ) DESC
    )                                               AS composite_rank
FROM normalised
ORDER BY tournament_name, composite_rank;
GO

PRINT '04_percentile_player_stats.sql loaded.';
GO
