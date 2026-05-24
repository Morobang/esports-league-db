-- =============================================================================
-- FILE:    06_seed_broadcast.sql
-- PURPOSE: Seed broadcasters, broadcast rights deals, and viewership logs
-- DEPENDS: 05_seed_business.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.broadcaster
-- =============================================================================

SET IDENTITY_INSERT ops.broadcaster ON;

INSERT INTO ops.broadcaster
    (broadcaster_id, name, platform, region, contact_email, website_url, is_active)
VALUES
    (1,  'ESL TV',              'Twitch',    'Global',        'esl@esl.tv',              'https://twitch.tv/esl_csgo',     1),
    (2,  'Valorant Champions',  'Twitch',    'Global',        'broadcast@riotgames.com', 'https://twitch.tv/valorant',     1),
    (3,  'Tekken Esports',      'YouTube',   'Global',        'broadcast@tekken.com',    'https://youtube.com/tekken',     1),
    (4,  'KOF Official',        'YouTube',   'East Asia',     'media@snk.co.jp',         'https://youtube.com/kofxv',      1),
    (5,  'SuperSport Esports',  'TV',        'South Africa',  'esports@supersport.com',  'https://supersport.com',         1),
    (6,  'Riot Games EN',       'Twitch',    'North America', 'na@riotgames.com',        'https://twitch.tv/riotgames',    1),
    (7,  'LEC Official',        'YouTube',   'EMEA',          'media@lolesports.com',    'https://youtube.com/lec',        1),
    (8,  'AfricanGamers TV',    'YouTube',   'Africa',        'media@africangamers.tv',  'https://youtube.com/africangamers',1);

SET IDENTITY_INSERT ops.broadcaster OFF;
GO

-- =============================================================================
-- ops.broadcast_rights
-- =============================================================================

SET IDENTITY_INSERT ops.broadcast_rights ON;

INSERT INTO ops.broadcast_rights
    (rights_id, broadcaster_id, tournament_id, rights_type, territory,
     fee, currency, start_date, end_date, status)
VALUES
    -- TWR EMEA Grand Finals (tournament 3)
    (1,  3, 3,  'Exclusive',      'Global',         80000.00,  'USD', '2025-09-01', '2025-09-30', 'Expired'),
    (2,  5, 3,  'Non-Exclusive',  'South Africa',    8000.00,  'USD', '2025-09-01', '2025-09-30', 'Expired'),

    -- TWR NA Championships (tournament 5)
    (3,  3, 5,  'Exclusive',      'North America',  40000.00,  'USD', '2025-07-01', '2025-07-31', 'Expired'),

    -- KOF EA Playoffs (tournament 9)
    (4,  4, 9,  'Exclusive',      'East Asia',      60000.00,  'USD', '2025-08-01', '2025-08-31', 'Expired'),
    (5,  8, 9,  'Non-Exclusive',  'Africa',          5000.00,  'USD', '2025-08-01', '2025-08-31', 'Expired'),

    -- VCT EMEA Stage 1 (tournament 10)
    (6,  2, 10, 'Exclusive',      'EMEA',          200000.00,  'USD', '2025-01-15', '2025-03-31', 'Expired'),
    (7,  6, 10, 'Non-Exclusive',  'North America',  60000.00,  'USD', '2025-01-15', '2025-03-31', 'Expired'),

    -- VCT EMEA Stage 2 (tournament 11)
    (8,  2, 11, 'Exclusive',      'EMEA',          200000.00,  'USD', '2025-04-01', '2025-06-30', 'Expired'),
    (9,  6, 11, 'Non-Exclusive',  'North America',  60000.00,  'USD', '2025-04-01', '2025-06-30', 'Expired'),

    -- VCT EMEA Playoffs (tournament 12)
    (10, 2, 12, 'Exclusive',      'EMEA',          500000.00,  'USD', '2025-07-01', '2025-08-31', 'Expired'),
    (11, 6, 12, 'Non-Exclusive',  'North America', 150000.00,  'USD', '2025-07-01', '2025-08-31', 'Expired'),
    (12, 5, 12, 'Non-Exclusive',  'South Africa',   15000.00,  'USD', '2025-07-01', '2025-08-31', 'Expired'),
    (13, 8, 12, 'Non-Exclusive',  'Africa',         12000.00,  'USD', '2025-07-01', '2025-08-31', 'Expired'),

    -- LEC Spring Playoffs (tournament 15)
    (14, 7, 15, 'Exclusive',      'EMEA',          800000.00,  'USD', '2025-03-01', '2025-04-30', 'Expired'),

    -- ESL Pro League S21 (tournament 16 — active)
    (15, 1, 16, 'Exclusive',      'Global',        900000.00,  'USD', '2025-09-01', '2025-10-31', 'Active'),
    (16, 5, 16, 'Non-Exclusive',  'South Africa',   20000.00,  'USD', '2025-09-01', '2025-10-31', 'Active');

SET IDENTITY_INSERT ops.broadcast_rights OFF;
GO

-- =============================================================================
-- ops.viewership_log  (viewer metrics per match per broadcast deal)
-- =============================================================================

SET IDENTITY_INSERT ops.viewership_log ON;

INSERT INTO ops.viewership_log
    (log_id, rights_id, match_id, peak_viewers, avg_viewers, stream_duration_min, chat_messages, logged_at)
VALUES
    -- TWR EMEA Grand Finals matches via Tekken Esports (rights 1)
    (1,  1,  11, 85400,   62300,   280, 1240000, '2025-09-20 22:30:00'),
    (2,  1,  12, 72100,   54800,   210,  980000, '2025-09-20 22:35:00'),
    (3,  1,  13, 148200, 112000,   125, 3400000, '2025-09-22 21:15:00'),
    -- South Africa sub-stream (rights 2)
    (4,  2,  11,  4200,    3100,   280,   48000, '2025-09-20 22:30:00'),
    (5,  2,  13,  9800,    7400,   125,  210000, '2025-09-22 21:15:00'),

    -- TWR NA Championships (rights 3)
    (6,  3,  29, 42100,   31500,   155,  620000, '2025-03-15 23:00:00'),
    (7,  3,  30, 38600,   28900,   130,  540000, '2025-03-15 23:05:00'),
    (8,  3,  31, 74300,   58200,   115, 1800000, '2025-04-05 21:30:00'),

    -- KOF EA Playoffs (rights 4)
    (9,  4,  NULL, 95000,  74000,  420, 2100000, '2025-08-17 21:00:00'),

    -- VCT EMEA Stage 1 — key matches (rights 6)
    (10, 6,  14,  280000, 198000,   90,  8400000, '2025-01-20 17:00:00'),
    (11, 6,  18,  340000, 254000,  105, 12200000, '2025-02-17 17:00:00'),
    (12, 6,  20,  520000, 398000,  115, 21000000, '2025-03-10 19:30:00'),
    (13, 6,  22,  680000, 512000,  175, 34000000, '2025-03-14 21:00:00'),
    -- NA stream (rights 7)
    (14, 7,  22,  145000, 108000,  175,  9200000, '2025-03-14 21:00:00'),

    -- VCT EMEA Playoffs (rights 10 — main EMEA stream)
    (15, 10, 23,  820000, 640000,  310, 52000000, '2025-08-01 22:30:00'),
    (16, 10, 24,  680000, 520000,  290, 42000000, '2025-08-02 22:30:00'),
    (17, 10, 25, 1240000, 980000,  175, 96000000, '2025-08-10 22:00:00'),  -- Grand Final
    -- NA stream (rights 11)
    (18, 11, 25,  420000, 318000,  175, 38000000, '2025-08-10 22:00:00'),
    -- SA stream (rights 12)
    (19, 12, 25,   28400,  21200,  175,  1800000, '2025-08-10 22:00:00'),
    -- Africa stream (rights 13)
    (20, 13, 25,   14200,  10800,  175,   820000, '2025-08-10 22:00:00'),

    -- LEC Spring Playoffs (rights 14)
    (21, 14, NULL, 480000, 360000, 420, 28000000, '2025-04-06 22:00:00');

SET IDENTITY_INSERT ops.viewership_log OFF;
GO

PRINT '06_seed_broadcast.sql: broadcaster (8), broadcast_rights (16), viewership_log (21) seeded.';
GO

-- =============================================================================
-- SEED COMPLETE — Summary
-- =============================================================================

SELECT 'comp.game'           AS [table], COUNT(*) AS rows FROM comp.game           UNION ALL
SELECT 'comp.region',                    COUNT(*)         FROM comp.region          UNION ALL
SELECT 'comp.league',                    COUNT(*)         FROM comp.league          UNION ALL
SELECT 'comp.team',                      COUNT(*)         FROM comp.team            UNION ALL
SELECT 'comp.player',                    COUNT(*)         FROM comp.player          UNION ALL
SELECT 'comp.staff',                     COUNT(*)         FROM comp.staff           UNION ALL
SELECT 'comp.contract',                  COUNT(*)         FROM comp.contract        UNION ALL
SELECT 'comp.tournament',                COUNT(*)         FROM comp.tournament      UNION ALL
SELECT 'comp.tournament_team',           COUNT(*)         FROM comp.tournament_team UNION ALL
SELECT 'comp.match',                     COUNT(*)         FROM comp.match           UNION ALL
SELECT 'comp.match_map',                 COUNT(*)         FROM comp.match_map       UNION ALL
SELECT 'comp.player_stat',               COUNT(*)         FROM comp.player_stat     UNION ALL
SELECT 'comp.player_rating',             COUNT(*)         FROM comp.player_rating   UNION ALL
SELECT 'comp.team_standing',             COUNT(*)         FROM comp.team_standing   UNION ALL
SELECT 'ops.venue',                      COUNT(*)         FROM ops.venue            UNION ALL
SELECT 'ops.event',                      COUNT(*)         FROM ops.event            UNION ALL
SELECT 'ops.ticket_tier',                COUNT(*)         FROM ops.ticket_tier      UNION ALL
SELECT 'ops.fan',                        COUNT(*)         FROM ops.fan              UNION ALL
SELECT 'ops.ticket_order',               COUNT(*)         FROM ops.ticket_order     UNION ALL
SELECT 'ops.sponsor',                    COUNT(*)         FROM ops.sponsor          UNION ALL
SELECT 'ops.sponsorship',                COUNT(*)         FROM ops.sponsorship      UNION ALL
SELECT 'ops.broadcaster',                COUNT(*)         FROM ops.broadcaster      UNION ALL
SELECT 'ops.broadcast_rights',           COUNT(*)         FROM ops.broadcast_rights UNION ALL
SELECT 'ops.viewership_log',             COUNT(*)         FROM ops.viewership_log;
GO
