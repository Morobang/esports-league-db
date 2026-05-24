-- =============================================================================
-- FILE:    01_recursive_bracket.sql
-- PURPOSE: Recursive CTEs to model and traverse tournament bracket structure,
--          compute bracket depth, and trace elimination paths
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- RECURSIVE CTE ANATOMY
--
-- WITH cte_name AS (
--     -- Anchor member: starting rows (non-recursive)
--     SELECT ...
--
--     UNION ALL
--
--     -- Recursive member: references cte_name, runs until no new rows
--     SELECT ... FROM cte_name JOIN ...
-- )
-- SELECT * FROM cte_name OPTION (MAXRECURSION 100);  -- safety cap
--
-- SQL Server default MAXRECURSION = 100. Set to 0 for unlimited (dangerous).
-- Always include a termination condition — a JOIN that eventually returns nothing.
-- =============================================================================

-- =============================================================================
-- QUERY 1: Build a bracket progression tree
--          Traces each team's path through a tournament from first match
--          to their final result. Useful for bracket visualisation.
-- =============================================================================

WITH bracket_seed AS (
    -- Anchor: all teams entering a tournament with their seed
    SELECT
        tt.tournament_id,
        tt.team_id,
        t.name                                      AS team_name,
        tt.seed,
        tt.final_placement,
        tt.is_eliminated,
        0                                           AS bracket_round,
        CAST(t.name AS NVARCHAR(MAX))               AS bracket_path,
        CAST(NULL AS INT)                           AS last_match_id,
        CAST(NULL AS NVARCHAR(50))                  AS last_stage
    FROM comp.tournament_team tt
    JOIN comp.team            t ON t.team_id = tt.team_id
    WHERE tt.tournament_id = 3   -- TWR EMEA Grand Finals (Double-Elim)

    UNION ALL

    -- Recursive: advance the team through each match they played
    SELECT
        bs.tournament_id,
        bs.team_id,
        bs.team_name,
        bs.seed,
        bs.final_placement,
        bs.is_eliminated,
        bs.bracket_round + 1,
        CAST(bs.bracket_path + ' → ' + m.stage AS NVARCHAR(MAX)),
        m.match_id,
        m.stage
    FROM bracket_seed bs
    JOIN comp.match   m
        ON  m.tournament_id = bs.tournament_id
        AND (m.team_a_id = bs.team_id OR m.team_b_id = bs.team_id)
        AND m.match_id > COALESCE(bs.last_match_id, 0)
        AND m.status = 'Completed'
    WHERE bs.bracket_round < 10  -- safety: cap at 10 rounds deep
)
SELECT
    team_name,
    seed,
    final_placement,
    bracket_round,
    last_stage                                      AS current_stage,
    bracket_path,
    is_eliminated
FROM bracket_seed
WHERE last_match_id IS NOT NULL   -- exclude the seed row itself
ORDER BY team_name, bracket_round
OPTION (MAXRECURSION 50);
GO

-- =============================================================================
-- QUERY 2: Recursive prize pool distribution
--          Starting from the total prize pool, distribute down each placement
--          using a standard esports split: 1st=40%, 2nd=25%, 3rd=15%, 4th=10%,
--          5th-6th=5% each
-- =============================================================================

WITH prize_splits (placement, pct_share) AS (
    VALUES (1, 40.0), (2, 25.0), (3, 15.0), (4, 10.0), (5, 5.0), (6, 5.0)
),
-- Wait — VALUES CTE not directly recursive. Build via number anchor:
placement_ladder AS (
    -- Anchor: first placement
    SELECT
        1                                           AS placement,
        40.0                                        AS pct_share,
        100.0                                       AS remaining_pct

    UNION ALL

    -- Recursive: each next placement takes its cut from what remains
    SELECT
        pl.placement + 1,
        CASE pl.placement + 1
            WHEN 2 THEN 25.0
            WHEN 3 THEN 15.0
            WHEN 4 THEN 10.0
            WHEN 5 THEN 5.0
            WHEN 6 THEN 5.0
            ELSE 0.0
        END,
        pl.remaining_pct - pl.pct_share
    FROM placement_ladder pl
    WHERE pl.placement < 6
),
tournament_prizes AS (
    SELECT
        tn.tournament_id,
        tn.name                                     AS tournament_name,
        tn.prize_pool,
        tn.currency,
        tt.team_id,
        t.name                                      AS team_name,
        tt.final_placement
    FROM comp.tournament      tn
    JOIN comp.tournament_team tt ON tt.tournament_id = tn.tournament_id
    JOIN comp.team            t  ON t.team_id        = tt.team_id
    WHERE tn.prize_pool IS NOT NULL
      AND tt.final_placement IS NOT NULL
      AND tt.final_placement <= 6
)
SELECT
    tp.tournament_name,
    tp.team_name,
    tp.final_placement,
    pl.pct_share                                    AS prize_pct,
    ROUND(tp.prize_pool * pl.pct_share / 100.0, 2) AS prize_amount,
    tp.currency,
    -- Running distributed total so far
    SUM(ROUND(tp.prize_pool * pl.pct_share / 100.0, 2)) OVER (
        PARTITION BY tp.tournament_id
        ORDER BY tp.final_placement
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cumulative_distributed,
    tp.prize_pool                                   AS total_prize_pool
FROM tournament_prizes  tp
JOIN placement_ladder   pl ON pl.placement = tp.final_placement
ORDER BY tp.tournament_name, tp.final_placement
OPTION (MAXRECURSION 10);
GO

-- =============================================================================
-- QUERY 3: Recursive date series — generate a match calendar
--          Builds a calendar between two dates using recursion,
--          then LEFT JOINs matches to show gaps (days with no matches)
-- =============================================================================

DECLARE @start_date DATE = '2025-01-01';
DECLARE @end_date   DATE = '2025-03-31';

WITH date_series AS (
    -- Anchor: start date
    SELECT @start_date                              AS cal_date

    UNION ALL

    -- Recursive: add one day until end date
    SELECT DATEADD(DAY, 1, ds.cal_date)
    FROM date_series ds
    WHERE ds.cal_date < @end_date
),
matches_by_day AS (
    SELECT
        CAST(played_at AS DATE)                     AS match_date,
        COUNT(*)                                    AS matches_played,
        SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed
    FROM comp.match
    WHERE played_at BETWEEN @start_date AND @end_date
    GROUP BY CAST(played_at AS DATE)
)
SELECT
    ds.cal_date,
    DATENAME(WEEKDAY, ds.cal_date)                  AS day_of_week,
    COALESCE(md.matches_played, 0)                  AS matches_scheduled,
    COALESCE(md.completed, 0)                       AS matches_completed,
    CASE WHEN md.match_date IS NULL THEN 'No Matches' ELSE 'Match Day' END
                                                    AS day_type
FROM date_series ds
LEFT JOIN matches_by_day md ON md.match_date = ds.cal_date
ORDER BY ds.cal_date
OPTION (MAXRECURSION 400);  -- 400 covers a full year
GO

-- =============================================================================
-- QUERY 4: Recursive team head-to-head record
--          Build a complete head-to-head table for all team pairs
--          in a tournament — who has the edge over who?
-- =============================================================================

WITH h2h_base AS (
    SELECT
        m.tournament_id,
        tn.name                                     AS tournament_name,
        m.team_a_id                                 AS team_id,
        m.team_b_id                                 AS opponent_id,
        CASE WHEN m.winner_id = m.team_a_id THEN 1 ELSE 0 END AS won,
        m.score_a                                   AS maps_for,
        m.score_b                                   AS maps_against
    FROM comp.match      m
    JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
    WHERE m.status = 'Completed'

    UNION ALL

    -- Mirror: opponent's perspective
    SELECT
        m.tournament_id,
        tn.name,
        m.team_b_id,
        m.team_a_id,
        CASE WHEN m.winner_id = m.team_b_id THEN 1 ELSE 0 END,
        m.score_b,
        m.score_a
    FROM comp.match      m
    JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
    WHERE m.status = 'Completed'
)
SELECT
    h.tournament_name,
    t1.name                                         AS team,
    t2.name                                         AS opponent,
    COUNT(*)                                        AS matches_played,
    SUM(h.won)                                      AS wins,
    COUNT(*) - SUM(h.won)                           AS losses,
    SUM(h.maps_for)                                 AS maps_won,
    SUM(h.maps_against)                             AS maps_lost,
    SUM(h.maps_for) - SUM(h.maps_against)           AS map_diff,
    -- H2H advantage label
    CASE
        WHEN SUM(h.won) > COUNT(*) - SUM(h.won) THEN 'Advantage'
        WHEN SUM(h.won) < COUNT(*) - SUM(h.won) THEN 'Disadvantage'
        ELSE 'Even'
    END                                             AS h2h_edge
FROM h2h_base   h
JOIN comp.team  t1 ON t1.team_id = h.team_id
JOIN comp.team  t2 ON t2.team_id = h.opponent_id
GROUP BY h.tournament_id, h.tournament_name, h.team_id, h.opponent_id, t1.name, t2.name
ORDER BY h.tournament_name, t1.name, wins DESC;
GO

PRINT '01_recursive_bracket.sql loaded.';
GO
