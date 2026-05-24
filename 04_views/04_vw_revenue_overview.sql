-- =============================================================================
-- FILE:    04_vw_revenue_overview.sql
-- PURPOSE: Executive revenue dashboard — sponsorship, ticket sales, and
--          broadcast fees rolled up by game, region, and quarter
-- DEPENDS: 03_seed_data/ (all data seeded)
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.vw_revenue_overview
-- One row per tournament per revenue stream (sponsorship / tickets / broadcast).
-- Pivotable by game, region, quarter, or league tier.
-- Used by: finance reports, sponsor ROI analysis, executive dashboards
-- =============================================================================

CREATE OR ALTER VIEW ops.vw_revenue_overview
AS
WITH sponsorship_rev AS (
    SELECT
        tn.tournament_id,
        tn.name                                         AS tournament_name,
        tn.start_date,
        l.league_id,
        l.name                                          AS league_name,
        l.tier                                          AS league_tier,
        g.game_id,
        g.name                                          AS game_name,
        r.region_id,
        r.name                                          AS region_name,
        'Sponsorship'                                   AS revenue_stream,
        sp.deal_value                                   AS amount,
        sp.currency,
        sp.sponsor_id,
        s.company_name                                  AS source_name,
        s.tier                                          AS sponsor_tier,
        sp.visibility_type
    FROM ops.sponsorship sp
    JOIN ops.sponsor      s   ON s.sponsor_id   = sp.sponsor_id
    JOIN comp.tournament  tn  ON tn.tournament_id = sp.tournament_id
    JOIN comp.league      l   ON l.league_id     = tn.league_id
    JOIN comp.game        g   ON g.game_id       = l.game_id
    JOIN comp.region      r   ON r.region_id     = l.region_id
    WHERE sp.tournament_id IS NOT NULL
      AND sp.status IN ('Active', 'Expired')
),
ticket_rev AS (
    SELECT
        e.tournament_id,
        tn.name                                         AS tournament_name,
        tn.start_date,
        l.league_id,
        l.name                                          AS league_name,
        l.tier                                          AS league_tier,
        g.game_id,
        g.name                                          AS game_name,
        r.region_id,
        r.name                                          AS region_name,
        'Ticket Sales'                                  AS revenue_stream,
        o.total_amount                                  AS amount,
        o.currency,
        NULL                                            AS sponsor_id,
        tt2.tier_name                                   AS source_name,
        NULL                                            AS sponsor_tier,
        NULL                                            AS visibility_type
    FROM ops.ticket_order   o
    JOIN ops.ticket_tier    tt2 ON tt2.tier_id     = o.tier_id
    JOIN ops.event          e   ON e.event_id      = tt2.event_id
    JOIN comp.tournament    tn  ON tn.tournament_id = e.tournament_id
    JOIN comp.league        l   ON l.league_id     = tn.league_id
    JOIN comp.game          g   ON g.game_id       = l.game_id
    JOIN comp.region        r   ON r.region_id     = l.region_id
    WHERE o.status = 'Confirmed'
),
broadcast_rev AS (
    SELECT
        br.tournament_id,
        tn.name                                         AS tournament_name,
        tn.start_date,
        l.league_id,
        l.name                                          AS league_name,
        l.tier                                          AS league_tier,
        g.game_id,
        g.name                                          AS game_name,
        r.region_id,
        r.name                                          AS region_name,
        'Broadcast Rights'                              AS revenue_stream,
        br.fee                                          AS amount,
        br.currency,
        NULL                                            AS sponsor_id,
        b.name                                          AS source_name,
        NULL                                            AS sponsor_tier,
        br.territory                                    AS visibility_type
    FROM ops.broadcast_rights  br
    JOIN ops.broadcaster       b   ON b.broadcaster_id = br.broadcaster_id
    JOIN comp.tournament       tn  ON tn.tournament_id = br.tournament_id
    JOIN comp.league           l   ON l.league_id      = tn.league_id
    JOIN comp.game             g   ON g.game_id        = l.game_id
    JOIN comp.region           r   ON r.region_id      = l.region_id
    WHERE br.status IN ('Active','Expired')
      AND br.fee IS NOT NULL
),
all_revenue AS (
    SELECT * FROM sponsorship_rev
    UNION ALL
    SELECT * FROM ticket_rev
    UNION ALL
    SELECT * FROM broadcast_rev
)
SELECT
    tournament_id,
    tournament_name,
    start_date,
    YEAR(start_date)                                    AS revenue_year,
    DATEPART(QUARTER, start_date)                       AS revenue_quarter,
    CONCAT('Q', DATEPART(QUARTER, start_date),
           '-', YEAR(start_date))                       AS year_quarter,
    league_id,
    league_name,
    league_tier,
    game_id,
    game_name,
    region_id,
    region_name,
    revenue_stream,
    source_name,
    sponsor_tier,
    visibility_type,
    COALESCE(amount, 0)                                 AS amount,
    currency,
    -- Running total of revenue per tournament
    SUM(COALESCE(amount, 0)) OVER (
        PARTITION BY tournament_id
        ORDER BY revenue_stream
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS running_tournament_total,
    -- Tournament's total revenue across all streams
    SUM(COALESCE(amount, 0)) OVER (
        PARTITION BY tournament_id
    )                                                   AS tournament_total_revenue,
    -- Game-level total revenue
    SUM(COALESCE(amount, 0)) OVER (
        PARTITION BY game_id
    )                                                   AS game_total_revenue,
    -- Region-level total revenue
    SUM(COALESCE(amount, 0)) OVER (
        PARTITION BY region_id
    )                                                   AS region_total_revenue
FROM all_revenue;
GO

-- Quick smoke tests:
--
-- Total revenue by game:
-- SELECT game_name, SUM(amount) AS total_revenue
-- FROM ops.vw_revenue_overview
-- GROUP BY game_name ORDER BY total_revenue DESC;
--
-- Revenue by stream and quarter:
-- SELECT year_quarter, revenue_stream, SUM(amount) AS total
-- FROM ops.vw_revenue_overview
-- GROUP BY year_quarter, revenue_stream
-- ORDER BY year_quarter, revenue_stream;
--
-- Top earning tournaments:
-- SELECT tournament_name, tournament_total_revenue
-- FROM ops.vw_revenue_overview
-- GROUP BY tournament_name, tournament_total_revenue
-- ORDER BY tournament_total_revenue DESC;

PRINT '04_vw_revenue_overview: view created.';
GO
