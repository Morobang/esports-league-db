-- =============================================================================
-- FILE:    03_vw_tournament_summary.sql
-- PURPOSE: Complete tournament summary — teams, matches, top performer,
--          viewership totals, and prize breakdown
-- DEPENDS: 03_seed_data/ (all data seeded)
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.vw_tournament_summary
-- One row per tournament.
-- Aggregates: team count, match count, total maps played, prize pool,
--             peak viewership, and winner details.
-- Used by: tournament history pages, executive dashboards, sponsor reports
-- =============================================================================

CREATE OR ALTER VIEW comp.vw_tournament_summary
AS
WITH match_counts AS (
    SELECT
        tournament_id,
        COUNT(*)                                        AS total_matches,
        SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed_matches,
        MIN(played_at)                                  AS first_match_played,
        MAX(played_at)                                  AS last_match_played
    FROM comp.match
    GROUP BY tournament_id
),
map_counts AS (
    SELECT
        m.tournament_id,
        COUNT(mm.map_id)                                AS total_maps_played,
        AVG(CAST(mm.duration_min AS DECIMAL(6,1)))      AS avg_map_duration_min
    FROM comp.match_map mm
    JOIN comp.match m ON m.match_id = mm.match_id
    GROUP BY m.tournament_id
),
viewership_totals AS (
    SELECT
        br.tournament_id,
        MAX(vl.peak_viewers)                            AS peak_viewers_global,
        SUM(vl.avg_viewers)                             AS sum_avg_viewers,
        COUNT(DISTINCT br.broadcaster_id)               AS broadcaster_count,
        SUM(vl.stream_duration_min)                     AS total_stream_minutes,
        SUM(vl.chat_messages)                           AS total_chat_messages
    FROM ops.viewership_log vl
    JOIN ops.broadcast_rights br ON br.rights_id = vl.rights_id
    WHERE vl.match_id IS NOT NULL
    GROUP BY br.tournament_id
),
sponsor_totals AS (
    SELECT
        tournament_id,
        SUM(deal_value)                                 AS total_sponsorship_value,
        COUNT(*)                                        AS sponsor_count
    FROM ops.sponsorship
    WHERE tournament_id IS NOT NULL
      AND status = 'Active'
    GROUP BY tournament_id
),
ticket_revenue AS (
    SELECT
        e.tournament_id,
        SUM(o.total_amount)                             AS total_ticket_revenue,
        SUM(o.quantity)                                 AS total_tickets_sold,
        COUNT(DISTINCT e.event_id)                      AS event_count
    FROM ops.ticket_order o
    JOIN ops.ticket_tier  tt ON tt.tier_id  = o.tier_id
    JOIN ops.event        e  ON e.event_id  = tt.event_id
    WHERE o.status = 'Confirmed'
    GROUP BY e.tournament_id
),
winner_info AS (
    SELECT
        tt.tournament_id,
        t.name                                          AS winner_name,
        t.tag                                           AS winner_tag
    FROM comp.tournament_team tt
    JOIN comp.team t ON t.team_id = tt.team_id
    WHERE tt.final_placement = 1
)
SELECT
    tn.tournament_id,
    tn.name                                             AS tournament_name,
    tn.format,
    tn.status,
    tn.is_lan,
    tn.prize_pool,
    tn.currency,
    tn.start_date,
    tn.end_date,
    DATEDIFF(DAY, tn.start_date, tn.end_date)           AS duration_days,

    -- League & game context
    l.name                                              AS league_name,
    l.tier                                              AS league_tier,
    l.season,
    g.name                                              AS game_name,
    r.name                                              AS region_name,

    -- Teams
    COUNT(DISTINCT tt2.team_id)                         AS teams_registered,
    wi.winner_name,
    wi.winner_tag,

    -- Matches
    COALESCE(mc.total_matches, 0)                       AS total_matches,
    COALESCE(mc.completed_matches, 0)                   AS completed_matches,
    mc.first_match_played,
    mc.last_match_played,

    -- Maps
    COALESCE(mp.total_maps_played, 0)                   AS total_maps_played,
    ROUND(COALESCE(mp.avg_map_duration_min, 0), 1)      AS avg_map_duration_min,

    -- Viewership
    COALESCE(vt.peak_viewers_global, 0)                 AS peak_viewers_global,
    COALESCE(vt.sum_avg_viewers, 0)                     AS total_avg_viewers,
    COALESCE(vt.broadcaster_count, 0)                   AS broadcaster_count,
    COALESCE(vt.total_chat_messages, 0)                 AS total_chat_messages,

    -- Revenue
    COALESCE(st.total_sponsorship_value, 0)             AS total_sponsorship_value,
    COALESCE(tr.total_ticket_revenue, 0)                AS total_ticket_revenue,
    COALESCE(tr.total_tickets_sold, 0)                  AS total_tickets_sold,
    COALESCE(tr.event_count, 0)                         AS events_held,
    COALESCE(st.total_sponsorship_value, 0)
        + COALESCE(tr.total_ticket_revenue, 0)          AS estimated_total_revenue

FROM comp.tournament tn
JOIN comp.league              l   ON l.league_id     = tn.league_id
JOIN comp.game                g   ON g.game_id       = l.game_id
JOIN comp.region              r   ON r.region_id     = l.region_id
LEFT JOIN comp.tournament_team tt2 ON tt2.tournament_id = tn.tournament_id
LEFT JOIN match_counts         mc  ON mc.tournament_id  = tn.tournament_id
LEFT JOIN map_counts           mp  ON mp.tournament_id  = tn.tournament_id
LEFT JOIN viewership_totals    vt  ON vt.tournament_id  = tn.tournament_id
LEFT JOIN sponsor_totals       st  ON st.tournament_id  = tn.tournament_id
LEFT JOIN ticket_revenue       tr  ON tr.tournament_id  = tn.tournament_id
LEFT JOIN winner_info          wi  ON wi.tournament_id  = tn.tournament_id
GROUP BY
    tn.tournament_id, tn.name, tn.format, tn.status, tn.is_lan,
    tn.prize_pool, tn.currency, tn.start_date, tn.end_date,
    l.name, l.tier, l.season, g.name, r.name,
    mc.total_matches, mc.completed_matches, mc.first_match_played, mc.last_match_played,
    mp.total_maps_played, mp.avg_map_duration_min,
    vt.peak_viewers_global, vt.sum_avg_viewers, vt.broadcaster_count, vt.total_chat_messages,
    st.total_sponsorship_value, tr.total_ticket_revenue, tr.total_tickets_sold, tr.event_count,
    wi.winner_name, wi.winner_tag;
GO

-- Quick smoke test
-- SELECT tournament_name, winner_name, total_matches, peak_viewers_global,
--        estimated_total_revenue
-- FROM comp.vw_tournament_summary
-- ORDER BY estimated_total_revenue DESC;

PRINT '03_vw_tournament_summary: view created.';
GO
