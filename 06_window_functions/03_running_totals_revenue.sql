-- =============================================================================
-- FILE:    03_running_totals_revenue.sql
-- PURPOSE: Running totals, moving averages, and cumulative share calculations
--          for ticket revenue and sponsorship using window frame clauses
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- WINDOW FRAME REFERENCE
--
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW  → standard running total
-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW          → 3-row moving average
-- ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING → grand total (same for all rows)
-- RANGE vs ROWS: RANGE includes all peers (same ORDER BY value); ROWS is positional
-- =============================================================================

-- =============================================================================
-- QUERY 1: Running ticket revenue total per event, ordered by sale date
--          Shows cumulative revenue as orders come in
-- =============================================================================

WITH daily_revenue AS (
    SELECT
        tt.event_id,
        e.name                                      AS event_name,
        CAST(o.ordered_at AS DATE)                  AS order_date,
        SUM(o.total_amount)                         AS daily_revenue,
        SUM(o.quantity)                             AS daily_tickets
    FROM ops.ticket_order  o
    JOIN ops.ticket_tier   tt ON tt.tier_id  = o.tier_id
    JOIN ops.event         e  ON e.event_id  = tt.event_id
    WHERE o.status = 'Confirmed'
    GROUP BY tt.event_id, e.name, CAST(o.ordered_at AS DATE)
)
SELECT
    event_name,
    order_date,
    daily_revenue,
    daily_tickets,

    -- Cumulative revenue since first sale for this event
    SUM(daily_revenue) OVER (
        PARTITION BY event_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cumulative_revenue,

    -- Cumulative tickets sold
    SUM(daily_tickets) OVER (
        PARTITION BY event_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cumulative_tickets,

    -- Total revenue for the event (denominator for share)
    SUM(daily_revenue) OVER (
        PARTITION BY event_id
    )                                               AS total_event_revenue,

    -- % of total revenue captured so far (cumulative share)
    ROUND(
        100.0 * SUM(daily_revenue) OVER (
            PARTITION BY event_id
            ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / NULLIF(SUM(daily_revenue) OVER (PARTITION BY event_id), 0),
    1)                                              AS pct_revenue_captured

FROM daily_revenue
ORDER BY event_name, order_date;
GO

-- =============================================================================
-- QUERY 2: 3-match rolling average viewership per tournament broadcast
--          Moving averages smooth out outlier match spikes
-- =============================================================================

WITH match_views AS (
    SELECT
        vl.rights_id,
        br.tournament_id,
        tn.name                                     AS tournament_name,
        b.name                                      AS broadcaster,
        m.match_id,
        m.stage,
        m.played_at,
        vl.peak_viewers,
        vl.avg_viewers,
        ROW_NUMBER() OVER (
            PARTITION BY vl.rights_id
            ORDER BY m.played_at
        )                                           AS match_seq
    FROM ops.viewership_log    vl
    JOIN ops.broadcast_rights  br ON br.rights_id    = vl.rights_id
    JOIN ops.broadcaster       b  ON b.broadcaster_id = br.broadcaster_id
    JOIN comp.tournament       tn ON tn.tournament_id = br.tournament_id
    JOIN comp.match            m  ON m.match_id       = vl.match_id
    WHERE vl.match_id IS NOT NULL
)
SELECT
    tournament_name,
    broadcaster,
    match_seq,
    stage,
    played_at,
    peak_viewers,
    avg_viewers,

    -- 3-match rolling average peak viewers
    ROUND(AVG(CAST(peak_viewers AS FLOAT)) OVER (
        PARTITION BY rights_id
        ORDER BY played_at
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0)                                           AS rolling_3_avg_peak,

    -- Running total of viewers across all matches in this broadcast deal
    SUM(avg_viewers) OVER (
        PARTITION BY rights_id
        ORDER BY played_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cumulative_avg_viewers,

    -- Peak viewers as % of overall max for this broadcast
    ROUND(
        100.0 * peak_viewers
        / NULLIF(MAX(peak_viewers) OVER (PARTITION BY rights_id), 0),
    1)                                              AS pct_of_peak_broadcast,

    -- Viewer growth vs previous match
    peak_viewers - LAG(peak_viewers, 1) OVER (
        PARTITION BY rights_id
        ORDER BY played_at
    )                                               AS viewer_growth

FROM match_views
ORDER BY tournament_name, broadcaster, match_seq;
GO

-- =============================================================================
-- QUERY 3: Sponsorship deal value running total by quarter
--          Shows how total committed deal value accumulates over time
-- =============================================================================

WITH sponsorship_dated AS (
    SELECT
        sp.sponsorship_id,
        sp.deal_value,
        sp.currency,
        sp.start_date,
        sp.visibility_type,
        sp.status,
        s.company_name,
        s.tier                                      AS sponsor_tier,
        YEAR(sp.start_date)                         AS deal_year,
        DATEPART(QUARTER, sp.start_date)            AS deal_quarter,
        CONCAT('Q', DATEPART(QUARTER, sp.start_date),
               '-', YEAR(sp.start_date))            AS year_quarter
    FROM ops.sponsorship sp
    JOIN ops.sponsor      s ON s.sponsor_id = sp.sponsor_id
    WHERE sp.currency = 'USD'
),
quarterly_totals AS (
    SELECT
        year_quarter,
        deal_year,
        deal_quarter,
        SUM(deal_value)                             AS quarterly_new_value,
        COUNT(*)                                    AS new_deals,
        MIN(start_date)                             AS quarter_start
    FROM sponsorship_dated
    GROUP BY year_quarter, deal_year, deal_quarter
)
SELECT
    year_quarter,
    quarterly_new_value,
    new_deals,

    -- Cumulative total committed sponsorship value over time
    SUM(quarterly_new_value) OVER (
        ORDER BY deal_year, deal_quarter
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS cumulative_sponsorship,

    -- Quarter-over-quarter growth
    quarterly_new_value - LAG(quarterly_new_value, 1, 0) OVER (
        ORDER BY deal_year, deal_quarter
    )                                               AS qoq_change,

    -- QoQ % growth
    ROUND(
        100.0 * (quarterly_new_value - LAG(quarterly_new_value, 1) OVER (
            ORDER BY deal_year, deal_quarter
        )) / NULLIF(LAG(quarterly_new_value, 1) OVER (
            ORDER BY deal_year, deal_quarter
        ), 0),
    1)                                              AS qoq_pct_growth,

    -- Share of total sponsorship portfolio this quarter represents
    ROUND(
        100.0 * quarterly_new_value
        / NULLIF(SUM(quarterly_new_value) OVER (), 0),
    1)                                              AS pct_of_total_portfolio

FROM quarterly_totals
ORDER BY deal_year, deal_quarter;
GO

-- =============================================================================
-- QUERY 4: First and last values — how has a team's standing evolved?
--          FIRST_VALUE and LAST_VALUE within a league season
-- =============================================================================

SELECT
    ts.league_id,
    l.name                                          AS league_name,
    t.name                                          AS team_name,
    ts.wins,
    ts.losses,
    ts.points,
    ts.maps_won - ts.maps_lost                      AS map_diff,

    -- Best points total in this league (leader's value)
    FIRST_VALUE(ts.points) OVER (
        PARTITION BY ts.league_id
        ORDER BY ts.points DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                               AS leader_points,

    -- Worst points total (bottom of table)
    LAST_VALUE(ts.points) OVER (
        PARTITION BY ts.league_id
        ORDER BY ts.points DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                               AS bottom_points,

    -- Gap to leader
    FIRST_VALUE(ts.points) OVER (
        PARTITION BY ts.league_id
        ORDER BY ts.points DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) - ts.points                                   AS pts_behind_leader,

    -- Current rank
    RANK() OVER (
        PARTITION BY ts.league_id
        ORDER BY ts.points DESC, (ts.maps_won - ts.maps_lost) DESC
    )                                               AS current_rank

FROM comp.team_standing ts
JOIN comp.league l ON l.league_id = ts.league_id
JOIN comp.team   t ON t.team_id   = ts.team_id
ORDER BY l.name, current_rank;
GO

PRINT '03_running_totals_revenue.sql loaded.';
GO
