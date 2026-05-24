-- =============================================================================
-- FILE:    02_match_momentum_lag_lead.sql
-- PURPOSE: Use LAG and LEAD to analyse match momentum, win streaks,
--          and score progression across a tournament bracket
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- QUERY 1: LAG — compare each team's score to their previous match
--          Did they improve, decline, or hold steady?
-- =============================================================================

WITH team_match_scores AS (
    -- Flatten matches so each team appears once per match with their score
    SELECT
        m.match_id,
        m.tournament_id,
        tn.name                                     AS tournament_name,
        m.team_a_id                                 AS team_id,
        t.name                                      AS team_name,
        m.score_a                                   AS maps_won,
        m.score_b                                   AS maps_lost,
        CASE WHEN m.winner_id = m.team_a_id THEN 1 ELSE 0 END AS won,
        m.stage,
        m.played_at
    FROM comp.match m
    JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
    JOIN comp.team       t  ON t.team_id        = m.team_a_id
    WHERE m.status = 'Completed'

    UNION ALL

    SELECT
        m.match_id,
        m.tournament_id,
        tn.name,
        m.team_b_id,
        t.name,
        m.score_b,
        m.score_a,
        CASE WHEN m.winner_id = m.team_b_id THEN 1 ELSE 0 END,
        m.stage,
        m.played_at
    FROM comp.match m
    JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
    JOIN comp.team       t  ON t.team_id        = m.team_b_id
    WHERE m.status = 'Completed'
)
SELECT
    tournament_name,
    team_name,
    stage,
    played_at,
    maps_won,
    maps_lost,
    won,

    -- Previous match result for this team in this tournament
    LAG(maps_won, 1) OVER (
        PARTITION BY tournament_id, team_id
        ORDER BY played_at
    )                                               AS prev_maps_won,

    LAG(won, 1) OVER (
        PARTITION BY tournament_id, team_id
        ORDER BY played_at
    )                                               AS prev_match_won,

    -- Score delta vs previous match
    maps_won - LAG(maps_won, 1, 0) OVER (
        PARTITION BY tournament_id, team_id
        ORDER BY played_at
    )                                               AS maps_won_delta,

    -- Next match result (look ahead)
    LEAD(maps_won, 1) OVER (
        PARTITION BY tournament_id, team_id
        ORDER BY played_at
    )                                               AS next_maps_won,

    -- Momentum label
    CASE
        WHEN won = 1
             AND LAG(won, 1) OVER (
                 PARTITION BY tournament_id, team_id ORDER BY played_at) = 1
        THEN 'Win Streak'
        WHEN won = 0
             AND LAG(won, 1) OVER (
                 PARTITION BY tournament_id, team_id ORDER BY played_at) = 0
        THEN 'Losing Run'
        WHEN won = 1
             AND LAG(won, 1) OVER (
                 PARTITION BY tournament_id, team_id ORDER BY played_at) = 0
        THEN 'Bounce Back'
        WHEN won = 0
             AND LAG(won, 1) OVER (
                 PARTITION BY tournament_id, team_id ORDER BY played_at) = 1
        THEN 'Form Drop'
        ELSE 'First Match'
    END                                             AS momentum_label

FROM team_match_scores
ORDER BY tournament_name, team_name, played_at;
GO

-- =============================================================================
-- QUERY 2: Win streak counter — longest current streak per team per tournament
--          Uses LAG chain with a gap-and-island approach
-- =============================================================================

WITH team_results AS (
    SELECT
        m.tournament_id,
        tn.name                                     AS tournament_name,
        t.team_id,
        t.name                                      AS team_name,
        m.match_id,
        m.played_at,
        CASE WHEN m.winner_id = t.team_id THEN 1 ELSE 0 END AS won
    FROM comp.match      m
    JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
    JOIN comp.team       t
        ON t.team_id = m.team_a_id OR t.team_id = m.team_b_id
    WHERE m.status = 'Completed'
),
-- Assign a group number that resets on every loss (gap-and-island)
streak_groups AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY tournament_id, team_id ORDER BY played_at)
        - ROW_NUMBER() OVER (PARTITION BY tournament_id, team_id, won ORDER BY played_at)
                                                    AS streak_group
    FROM team_results
),
streak_lengths AS (
    SELECT
        tournament_id,
        tournament_name,
        team_id,
        team_name,
        won,
        streak_group,
        COUNT(*)                                    AS streak_length,
        MIN(played_at)                              AS streak_start,
        MAX(played_at)                              AS streak_end
    FROM streak_groups
    GROUP BY tournament_id, tournament_name, team_id, team_name, won, streak_group
)
SELECT
    tournament_name,
    team_name,
    CASE WHEN won = 1 THEN 'Win Streak' ELSE 'Loss Streak' END AS streak_type,
    streak_length,
    streak_start,
    streak_end,
    -- Rank streaks within each tournament by length
    RANK() OVER (
        PARTITION BY tournament_id, won
        ORDER BY streak_length DESC
    )                                               AS streak_rank
FROM streak_lengths
WHERE won = 1        -- filter to win streaks only; remove for loss streaks too
ORDER BY tournament_name, streak_length DESC;
GO

-- =============================================================================
-- QUERY 3: Map-level momentum within a Bo5 series
--          How does score progression shift map by map?
-- =============================================================================

SELECT
    m.match_id,
    tn.name                                         AS tournament_name,
    ta.name                                         AS team_a,
    tb.name                                         AS team_b,
    mm.map_number,
    mm.map_name,
    mm.team_a_score,
    mm.team_b_score,

    -- Cumulative score through the series for each team
    SUM(mm.team_a_score) OVER (
        PARTITION BY mm.match_id
        ORDER BY mm.map_number
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cum_team_a_score,

    SUM(mm.team_b_score) OVER (
        PARTITION BY mm.match_id
        ORDER BY mm.map_number
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cum_team_b_score,

    -- Score gap at each map point (positive = team_a leading)
    SUM(mm.team_a_score - mm.team_b_score) OVER (
        PARTITION BY mm.match_id
        ORDER BY mm.map_number
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS running_score_gap,

    -- Who won this individual map?
    CASE
        WHEN mm.team_a_score > mm.team_b_score THEN ta.name
        WHEN mm.team_b_score > mm.team_a_score THEN tb.name
        ELSE 'Draw'
    END                                             AS map_winner,

    -- Previous map winner (momentum context)
    LAG(CASE
        WHEN mm.team_a_score > mm.team_b_score THEN ta.name
        WHEN mm.team_b_score > mm.team_a_score THEN tb.name
        ELSE 'Draw'
    END, 1) OVER (
        PARTITION BY mm.match_id
        ORDER BY mm.map_number
    )                                               AS prev_map_winner,

    mm.duration_min

FROM comp.match_map mm
JOIN comp.match      m  ON m.match_id       = mm.match_id
JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
JOIN comp.team       ta ON ta.team_id       = m.team_a_id
JOIN comp.team       tb ON tb.team_id       = m.team_b_id
WHERE m.best_of >= 3        -- only multi-map series
ORDER BY m.match_id, mm.map_number;
GO

PRINT '02_match_momentum_lag_lead.sql loaded.';
GO
