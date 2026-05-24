-- =============================================================================
-- FILE:    03_contract_expiry_pipeline.sql
-- PURPOSE: Multi-stage CTE pipeline for contract risk analysis,
--          expiry forecasting, and salary cap planning
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- QUERY 1: Contract expiry risk dashboard
--          Classifies every active contract into a risk tier,
--          estimates replacement cost, and flags high-value players at risk
-- =============================================================================

WITH active_contracts AS (
    -- Step 1: load all active contracts with player and team context
    SELECT
        c.contract_id,
        c.player_id,
        c.team_id,
        c.salary_monthly,
        c.currency,
        c.start_date,
        c.end_date,
        c.buyout_clause,
        p.username,
        p.role,
        p.nationality,
        t.name                                      AS team_name,
        r.name                                      AS region_name,
        DATEDIFF(DAY,  GETUTCDATE(), c.end_date)    AS days_to_expiry,
        DATEDIFF(MONTH, c.start_date, c.end_date)   AS contract_length_months,
        c.salary_monthly * DATEDIFF(MONTH, GETUTCDATE(), c.end_date)
                                                    AS remaining_value
    FROM comp.contract c
    JOIN comp.player   p ON p.player_id = c.player_id
    JOIN comp.team     t ON t.team_id   = c.team_id
    JOIN comp.region   r ON r.region_id = t.region_id
    WHERE c.status = 'Active'
),
player_perf_scores AS (
    -- Step 2: compute each player's performance score from stats
    SELECT
        ps.player_id,
        COUNT(DISTINCT ps.match_id)                 AS career_matches,
        SUM(ps.kills)                               AS career_kills,
        SUM(CAST(ps.mvp_flag AS INT))               AS career_mvps,
        CASE
            WHEN SUM(ps.deaths) = 0
            THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
            ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                 / NULLIF(SUM(ps.deaths), 0)
        END                                         AS career_kda,
        AVG(CAST(ps.damage_dealt AS FLOAT))         AS avg_damage
    FROM comp.player_stat ps
    JOIN comp.match       m ON m.match_id = ps.match_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id
),
contract_risk AS (
    -- Step 3: classify each contract by risk and value
    SELECT
        ac.*,
        COALESCE(pps.career_matches, 0)             AS career_matches,
        ROUND(COALESCE(pps.career_kda, 0), 2)       AS career_kda,
        COALESCE(pps.career_mvps, 0)                AS career_mvps,

        -- Risk classification
        CASE
            WHEN ac.days_to_expiry <= 30  THEN 'Critical'   -- expiring this month
            WHEN ac.days_to_expiry <= 90  THEN 'High'       -- expiring this quarter
            WHEN ac.days_to_expiry <= 180 THEN 'Medium'     -- expiring in 6 months
            ELSE                               'Low'
        END                                         AS expiry_risk,

        -- Value tier (based on salary)
        CASE
            WHEN ac.salary_monthly >= 7000 THEN 'Franchise'
            WHEN ac.salary_monthly >= 4000 THEN 'Core'
            WHEN ac.salary_monthly >= 2000 THEN 'Rotation'
            ELSE                                'Development'
        END                                         AS value_tier,

        -- Estimated market replacement cost (1.2x current for Core+, 1.0x others)
        ROUND(
            ac.salary_monthly * CASE
                WHEN ac.salary_monthly >= 4000 THEN 1.25
                ELSE 1.0
            END,
        0)                                          AS est_replacement_cost,

        -- Priority score: high value + high risk = highest priority
        CASE
            WHEN ac.days_to_expiry <= 90
                 AND ac.salary_monthly >= 4000 THEN 1  -- renew immediately
            WHEN ac.days_to_expiry <= 180
                 AND ac.salary_monthly >= 4000 THEN 2
            WHEN ac.days_to_expiry <= 90  THEN 3
            ELSE 4
        END                                         AS renewal_priority
    FROM active_contracts   ac
    LEFT JOIN player_perf_scores pps ON pps.player_id = ac.player_id
)
SELECT
    renewal_priority,
    expiry_risk,
    value_tier,
    username,
    role,
    team_name,
    region_name,
    salary_monthly,
    currency,
    end_date,
    days_to_expiry,
    remaining_value,
    buyout_clause,
    est_replacement_cost,
    est_replacement_cost - salary_monthly           AS monthly_replacement_premium,
    career_matches,
    career_kda,
    career_mvps,
    -- Alert flag for management
    CASE
        WHEN renewal_priority = 1 THEN '🔴 RENEW NOW'
        WHEN renewal_priority = 2 THEN '🟠 START TALKS'
        WHEN renewal_priority = 3 THEN '🟡 MONITOR'
        ELSE                           '🟢 STABLE'
    END                                             AS action_flag
FROM contract_risk
ORDER BY renewal_priority, days_to_expiry, salary_monthly DESC;
GO

-- =============================================================================
-- QUERY 2: Team salary cap projection — 6-month rolling wage bill forecast
--          Shows how total monthly spend evolves as contracts expire
-- =============================================================================

WITH contract_timeline AS (
    SELECT
        c.team_id,
        t.name                                      AS team_name,
        c.player_id,
        p.username,
        c.salary_monthly,
        c.end_date,
        -- Which calendar months is this contract still active?
        -- Generate one row per remaining month
        DATEDIFF(MONTH, GETUTCDATE(), c.end_date)   AS months_remaining
    FROM comp.contract c
    JOIN comp.player   p ON p.player_id = c.player_id
    JOIN comp.team     t ON t.team_id   = c.team_id
    WHERE c.status = 'Active'
      AND c.end_date >= GETUTCDATE()
),
month_series AS (
    -- Recursive: generate months 0–6 ahead
    SELECT 0                                        AS month_offset
    UNION ALL
    SELECT month_offset + 1
    FROM month_series
    WHERE month_offset < 6
),
monthly_wage_projection AS (
    SELECT
        ct.team_id,
        ct.team_name,
        ms.month_offset,
        EOMONTH(DATEADD(MONTH, ms.month_offset, GETUTCDATE()))
                                                    AS projection_month,
        ct.username,
        ct.salary_monthly,
        -- Is this contract still active in this projected month?
        CASE
            WHEN ms.month_offset <= ct.months_remaining THEN ct.salary_monthly
            ELSE 0
        END                                         AS projected_salary
    FROM contract_timeline ct
    CROSS JOIN month_series ms
)
SELECT
    team_name,
    projection_month,
    month_offset,
    SUM(projected_salary)                           AS projected_wage_bill,
    COUNT(CASE WHEN projected_salary > 0 THEN 1 END) AS active_contracts,
    -- Month-over-month change in wage bill
    SUM(projected_salary) - LAG(SUM(projected_salary), 1) OVER (
        PARTITION BY team_id
        ORDER BY month_offset
    )                                               AS mom_wage_change
FROM monthly_wage_projection
GROUP BY team_id, team_name, projection_month, month_offset
ORDER BY team_name, month_offset
OPTION (MAXRECURSION 10);
GO

-- =============================================================================
-- QUERY 3: Free agent market — players whose contracts expire within 90 days
--          with their performance stats for scouting purposes
-- =============================================================================

WITH expiring_soon AS (
    SELECT
        c.player_id,
        c.team_id,
        c.salary_monthly,
        c.end_date,
        DATEDIFF(DAY, GETUTCDATE(), c.end_date)     AS days_remaining
    FROM comp.contract c
    WHERE c.status = 'Active'
      AND c.end_date <= DATEADD(DAY, 90, GETUTCDATE())
),
player_stats AS (
    SELECT
        ps.player_id,
        COUNT(DISTINCT m.tournament_id)             AS tournaments,
        COUNT(DISTINCT ps.match_id)                 AS matches,
        SUM(ps.kills)                               AS kills,
        SUM(CAST(ps.mvp_flag AS INT))               AS mvps,
        ROUND(
            CASE WHEN SUM(ps.deaths) = 0
                 THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                 ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                      / NULLIF(SUM(ps.deaths), 0)
            END, 2)                                 AS career_kda
    FROM comp.player_stat ps
    JOIN comp.match       m ON m.match_id = ps.match_id
    WHERE m.status = 'Completed'
    GROUP BY ps.player_id
)
SELECT
    p.username,
    p.real_name,
    p.nationality,
    p.role,
    t.name                                          AS current_team,
    r.name                                          AS region,
    es.salary_monthly                               AS current_salary,
    es.end_date                                     AS contract_expires,
    es.days_remaining,
    COALESCE(pst.tournaments, 0)                    AS tournaments_played,
    COALESCE(pst.matches, 0)                        AS career_matches,
    COALESCE(pst.kills, 0)                          AS career_kills,
    COALESCE(pst.career_kda, 0)                     AS career_kda,
    COALESCE(pst.mvps, 0)                           AS career_mvps,
    -- Estimated market value based on performance
    ROUND(
        es.salary_monthly * (1 + COALESCE(pst.career_kda, 1) / 10.0),
    0)                                              AS est_market_value
FROM expiring_soon    es
JOIN comp.player      p   ON p.player_id  = es.player_id
JOIN comp.team        t   ON t.team_id    = es.team_id
JOIN comp.region      r   ON r.region_id  = t.region_id
LEFT JOIN player_stats pst ON pst.player_id = es.player_id
ORDER BY es.days_remaining, es.salary_monthly DESC;
GO

PRINT '03_contract_expiry_pipeline.sql loaded.';
GO
