-- =============================================================================
-- FILE:    05_seed_business.sql
-- PURPOSE: Seed venues, events, ticket tiers, fans, ticket orders,
--          sponsors and sponsorship deals
-- DEPENDS: 04_seed_matches_stats.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.venue
-- =============================================================================

SET IDENTITY_INSERT ops.venue ON;

INSERT INTO ops.venue (venue_id, region_id, name, city, country, capacity, address, is_active)
VALUES
    (1, 2, 'ESL Arena Cologne',         'Cologne',      'Germany',      8000,  'Lanxess Arena, Willy-Brandt-Platz 1', 1),
    (2, 1, 'Esports Stadium Arlington', 'Arlington',    'USA',          2500,  '1200 Ballpark Way, Arlington, TX',    1),
    (3, 3, 'Nasrec Expo Centre',        'Johannesburg', 'South Africa', 1500,  'Gate 3, Nasrec Rd, Johannesburg',     1),
    (4, 5, 'TGS Arena Tokyo',           'Tokyo',        'Japan',        3000,  'Makuhari Messe, Chiba',               1),
    (4, 4, 'Marina Bay Arena',          'Singapore',    'Singapore',    2000,  '10 Bayfront Ave, Singapore',          1);

SET IDENTITY_INSERT ops.venue OFF;
GO

-- Fix duplicate venue_id — re-insert Singapore venue
DELETE FROM ops.venue WHERE venue_id = 4 AND city = 'Singapore';
INSERT INTO ops.venue (region_id, name, city, country, capacity, address, is_active)
VALUES (4, 'Marina Bay Arena', 'Singapore', 'Singapore', 2000, '10 Bayfront Ave, Singapore', 1);
GO

-- =============================================================================
-- ops.event
-- =============================================================================

SET IDENTITY_INSERT ops.event ON;

INSERT INTO ops.event
    (event_id, tournament_id, venue_id, name, event_type, start_datetime, end_datetime,
     expected_attendance, actual_attendance, stream_url, status)
VALUES
    -- TWR EMEA Grand Finals (tournament 3)
    (1, 3, 1, 'TWR EMEA Grand Finals - Day 1', 'SemiFinal',
     '2025-09-20 13:00:00', '2025-09-20 22:00:00', 6000, 5840,
     'https://twitch.tv/tekken_esports', 'Completed'),
    (2, 3, 1, 'TWR EMEA Grand Finals - Day 2', 'GrandFinal',
     '2025-09-22 14:00:00', '2025-09-22 21:00:00', 6000, 6000,
     'https://twitch.tv/tekken_esports', 'Completed'),

    -- VCT EMEA Playoffs (tournament 12)
    (3, 12, 1, 'VCT EMEA Playoffs Opening Day',  'Playoff',
     '2025-08-01 14:00:00', '2025-08-01 22:00:00', 7500, 7200,
     'https://twitch.tv/valorant', 'Completed'),
    (4, 12, 1, 'VCT EMEA Playoffs Day 2',        'Playoff',
     '2025-08-02 14:00:00', '2025-08-02 22:00:00', 7500, 6900,
     'https://twitch.tv/valorant', 'Completed'),
    (5, 12, 1, 'VCT EMEA Grand Final',           'GrandFinal',
     '2025-08-10 15:00:00', '2025-08-10 22:00:00', 8000, 8000,
     'https://twitch.tv/valorant', 'Completed'),

    -- TWR NA Championships (tournament 5)
    (6, 5, 2, 'TWR NA Championships',            'GrandFinal',
     '2025-07-10 14:00:00', '2025-07-12 21:00:00', 2000, 1850,
     'https://youtube.com/tekken', 'Completed'),

    -- KOF EA Playoffs (tournament 9)
    (7, 9, 4, 'KOF EA Playoffs',                 'Playoff',
     '2025-08-15 10:00:00', '2025-08-17 20:00:00', 2800, 2600,
     'https://youtube.com/kofxv', 'Completed'),

    -- ESL Pro League S21 — upcoming events
    (8, 16, 1, 'ESL Pro League S21 Playoffs',    'Playoff',
     '2025-10-15 14:00:00', '2025-10-20 21:00:00', 8000, NULL,
     'https://twitch.tv/esl_csgo', 'Scheduled');

SET IDENTITY_INSERT ops.event OFF;
GO

-- =============================================================================
-- ops.ticket_tier
-- =============================================================================

SET IDENTITY_INSERT ops.ticket_tier ON;

INSERT INTO ops.ticket_tier
    (tier_id, event_id, tier_name, price, currency, total_seats, seats_sold, sale_start, sale_end)
VALUES
    -- Event 1 (TWR Grand Finals Day 1)
    (1,  1, 'General',   25.00, 'USD', 4000, 3900, '2025-07-01 09:00:00', '2025-09-19 23:59:00'),
    (2,  1, 'VIP',       75.00, 'USD',  800,  780, '2025-07-01 09:00:00', '2025-09-19 23:59:00'),
    (3,  1, 'Premium',  150.00, 'USD',  200,  160, '2025-07-01 09:00:00', '2025-09-19 23:59:00'),

    -- Event 2 (TWR Grand Finals Day 2)
    (4,  2, 'General',   35.00, 'USD', 4000, 4000, '2025-07-01 09:00:00', '2025-09-21 23:59:00'),
    (5,  2, 'VIP',      100.00, 'USD',  800,  800, '2025-07-01 09:00:00', '2025-09-21 23:59:00'),
    (6,  2, 'Premium',  200.00, 'USD',  200,  200, '2025-07-01 09:00:00', '2025-09-21 23:59:00'),

    -- Event 3 (VCT Playoffs Day 1)
    (7,  3, 'General',   30.00, 'USD', 5500, 5300, '2025-05-01 09:00:00', '2025-07-31 23:59:00'),
    (8,  3, 'VIP',       90.00, 'USD', 1500, 1490, '2025-05-01 09:00:00', '2025-07-31 23:59:00'),
    (9,  3, 'Premium',  180.00, 'USD',  500,  410, '2025-05-01 09:00:00', '2025-07-31 23:59:00'),

    -- Event 5 (VCT EMEA Grand Final)
    (10, 5, 'General',   45.00, 'USD', 5500, 5500, '2025-05-01 09:00:00', '2025-08-09 23:59:00'),
    (11, 5, 'VIP',      130.00, 'USD', 1500, 1500, '2025-05-01 09:00:00', '2025-08-09 23:59:00'),
    (12, 5, 'Premium',  250.00, 'USD',  500,  500, '2025-05-01 09:00:00', '2025-08-09 23:59:00'),
    (13, 5, 'Courtside',500.00, 'USD',  100,  100, '2025-05-01 09:00:00', '2025-08-09 23:59:00'),

    -- Event 8 (ESL Pro League — upcoming)
    (14, 8, 'General',   40.00, 'USD', 5000,  820, '2025-09-01 09:00:00', '2025-10-14 23:59:00'),
    (15, 8, 'VIP',      120.00, 'USD', 1500,  240, '2025-09-01 09:00:00', '2025-10-14 23:59:00'),
    (16, 8, 'Premium',  220.00, 'USD',  500,   62, '2025-09-01 09:00:00', '2025-10-14 23:59:00');

SET IDENTITY_INSERT ops.ticket_tier OFF;
GO

-- =============================================================================
-- ops.fan  (50 registered fans)
-- =============================================================================

SET IDENTITY_INSERT ops.fan ON;

INSERT INTO ops.fan (fan_id, username, email, country, favourite_team_id, registered_at, last_login, is_active)
VALUES
    (1,  'ThunderFan_ZA',   'thunder@gmail.com',     'South Africa', 3,  '2022-01-10 10:00:00', '2025-09-20 09:00:00', 1),
    (2,  'EchoForce_Stan',  'echostan@hotmail.com',  'Portugal',     1,  '2021-05-22 11:30:00', '2025-09-22 20:00:00', 1),
    (3,  'NightHawk_Fan',   'nhfan@yahoo.com',       'USA',          2,  '2020-08-15 09:00:00', '2025-07-12 18:00:00', 1),
    (4,  'Valorant_EMEA',   'vct_emea@outlook.com',  'Germany',      11, '2021-11-01 14:00:00', '2025-08-10 22:30:00', 1),
    (5,  'ApexHunterMVP',   'apex_mvp@gmail.com',    'UK',           11, '2022-03-14 16:00:00', '2025-08-10 21:00:00', 1),
    (6,  'CipherArmy',      'cipher_fan@gmail.com',  'Germany',      17, '2019-07-04 08:00:00', '2025-09-15 10:00:00', 1),
    (7,  'SakuraStanAccount','sakura_stan@jp.net',   'Japan',        4,  '2020-01-20 12:00:00', '2025-08-17 19:00:00', 1),
    (8,  'KingDamini',      'damini_thabo@sa.co.za', 'South Africa', 3,  '2021-06-01 07:30:00', '2025-09-20 14:00:00', 1),
    (9,  'VortexRider',     'vortex99@gmail.com',    'France',       5,  '2020-04-12 20:00:00', '2025-06-30 21:00:00', 1),
    (10, 'IronPulseFan',    'ipfan@usa.net',         'USA',          2,  '2021-02-28 15:00:00', '2025-07-12 17:00:00', 1),
    (11, 'PhantomSEA_Fan',  'phantomfan@sg.com',     'Singapore',    6,  '2022-08-01 18:00:00', '2025-08-15 20:00:00', 1),
    (12, 'UbuntuPride',     'ubuntu_pride@za.co.za', 'South Africa', 12, '2022-02-14 11:00:00', '2025-04-20 16:00:00', 1),
    (13, 'FrostGiantsGG',   'fg_forever@eu.com',     'Norway',       15, '2020-09-01 09:00:00', '2025-04-06 22:00:00', 1),
    (14, 'RedwoodRoyals',   'redwood_fam@usa.net',   'USA',          16, '2019-11-11 13:00:00', '2025-04-05 21:00:00', 1),
    (15, 'ESLAddict',       'esl_addict@de.com',     'Germany',      17, '2018-12-01 10:00:00', '2025-09-22 12:00:00', 1),
    (16, 'GridLionsFam',    'gridlions@usa.net',     'USA',          8,  '2021-03-20 14:00:00', '2025-07-11 20:00:00', 1),
    (17, 'KOFKingFan',      'kofking@jp.net',        'Japan',        4,  '2020-05-05 09:00:00', '2025-08-17 18:00:00', 1),
    (18, 'DigitalFC_EU',    'dfc_eu@outlook.com',    'Ireland',      7,  '2022-07-01 16:00:00', '2025-08-31 11:00:00', 1),
    (19, 'SignalFireFan',   'signalfire@fr.com',     'France',       11, '2021-09-15 18:00:00', '2025-08-10 23:00:00', 1),
    (20, 'DesertHawksFan',  'dhfan@ae.com',          'UAE',          20, '2022-01-01 12:00:00', '2025-09-01 14:00:00', 1),
    -- Additional fans for query variety
    (21, 'TekkenWorldFan',  'twfan@email.com',       'USA',          1,  '2023-01-15 10:00:00', '2025-09-21 10:00:00', 1),
    (22, 'AfricanGamer',    'africangamer@za.net',   'South Africa', 12, '2023-03-10 09:00:00', '2025-04-19 15:00:00', 1),
    (23, 'VCT_STAN',        'vctstan@gmail.com',     'Spain',        11, '2022-10-01 11:00:00', '2025-08-09 22:00:00', 1),
    (24, 'CipherHeadshot',  'headshot_h@eu.com',     'Czech',        17, '2020-06-15 13:00:00', '2025-10-01 10:00:00', 1),
    (25, 'AmazoniaBR',      'amazonia_fan@br.com',   'Brazil',       9,  '2021-08-22 19:00:00', '2025-09-30 21:00:00', 1);

SET IDENTITY_INSERT ops.fan OFF;
GO

-- =============================================================================
-- ops.ticket_order  (realistic purchase data)
-- =============================================================================

SET IDENTITY_INSERT ops.ticket_order ON;

INSERT INTO ops.ticket_order
    (order_id, fan_id, tier_id, quantity, unit_price, total_amount, currency, status, payment_ref, ordered_at)
VALUES
    -- TWR Grand Finals orders (event 1 & 2)
    (1,  2,  1,  2, 25.00,   50.00,  'USD', 'Confirmed', 'PAY-001-EF',  '2025-07-15 10:30:00'),
    (2,  2,  4,  2, 35.00,   70.00,  'USD', 'Confirmed', 'PAY-002-EF',  '2025-07-15 10:35:00'),
    (3,  2,  5,  1, 100.00, 100.00,  'USD', 'Confirmed', 'PAY-003-EF',  '2025-07-15 10:40:00'),
    (4,  9,  1,  4, 25.00,  100.00,  'USD', 'Confirmed', 'PAY-004-VTX', '2025-07-20 14:00:00'),
    (5,  1,  1,  2, 25.00,   50.00,  'USD', 'Confirmed', 'PAY-005-ZA',  '2025-07-22 09:00:00'),
    (6,  21, 2,  2, 75.00,  150.00,  'USD', 'Confirmed', 'PAY-006-VIP', '2025-08-01 11:00:00'),
    (7,  8,  1,  3, 25.00,   75.00,  'USD', 'Confirmed', 'PAY-007-ZA',  '2025-08-10 08:00:00'),
    (8,  3,  3,  1, 150.00, 150.00,  'USD', 'Cancelled', 'PAY-008-CX',  '2025-07-30 16:00:00'),

    -- VCT EMEA Grand Final orders (event 5)
    (9,  4,  10, 2, 45.00,   90.00,  'USD', 'Confirmed', 'PAY-009-VCT', '2025-05-20 12:00:00'),
    (10, 5,  11, 1, 130.00, 130.00,  'USD', 'Confirmed', 'PAY-010-VCT', '2025-05-20 12:05:00'),
    (11, 19, 10, 4, 45.00,  180.00,  'USD', 'Confirmed', 'PAY-011-VCT', '2025-05-25 14:00:00'),
    (12, 23, 10, 2, 45.00,   90.00,  'USD', 'Confirmed', 'PAY-012-VCT', '2025-06-01 11:00:00'),
    (13, 4,  12, 2, 250.00, 500.00,  'USD', 'Confirmed', 'PAY-013-PRE', '2025-06-10 09:00:00'),
    (14, 5,  13, 2, 500.00,1000.00,  'USD', 'Confirmed', 'PAY-014-CTS', '2025-06-15 10:00:00'),
    (15, 6,  10, 3, 45.00,  135.00,  'USD', 'Confirmed', 'PAY-015-VCT', '2025-07-01 15:00:00'),
    (16, 24, 11, 1, 130.00, 130.00,  'USD', 'Confirmed', 'PAY-016-VCT', '2025-07-15 16:00:00'),

    -- VCT Playoffs Day 1 orders (event 3)
    (17, 4,  7,  2, 30.00,   60.00,  'USD', 'Confirmed', 'PAY-017-PO',  '2025-05-05 10:00:00'),
    (18, 23, 8,  1, 90.00,   90.00,  'USD', 'Confirmed', 'PAY-018-PO',  '2025-05-10 11:00:00'),
    (19, 19, 7,  3, 30.00,   90.00,  'USD', 'Confirmed', 'PAY-019-PO',  '2025-05-12 13:00:00'),

    -- ESL upcoming orders (event 8)
    (20, 6,  14, 4, 40.00,  160.00,  'USD', 'Confirmed', 'PAY-020-ESL', '2025-09-05 09:00:00'),
    (21, 15, 15, 2, 120.00, 240.00,  'USD', 'Confirmed', 'PAY-021-ESL', '2025-09-06 10:00:00'),
    (22, 24, 14, 2, 40.00,   80.00,  'USD', 'Confirmed', 'PAY-022-ESL', '2025-09-10 14:00:00'),
    (23, 25, 16, 1, 220.00, 220.00,  'USD', 'Pending',   NULL,          '2025-10-01 08:00:00');

SET IDENTITY_INSERT ops.ticket_order OFF;
GO

-- =============================================================================
-- ops.sponsor
-- =============================================================================

SET IDENTITY_INSERT ops.sponsor ON;

INSERT INTO ops.sponsor (sponsor_id, company_name, industry, website_url, contact_email, tier, is_active)
VALUES
    (1,  'RedBull Esports',      'Energy Drink',    'https://redbull.com',       'esports@redbull.com',     'Title',   1),
    (2,  'Logitech G',           'Gaming Hardware',  'https://logitechg.com',     'partnerships@logitech.com','Gold',    1),
    (3,  'Intel Gaming',         'Technology',       'https://intel.com',         'esports@intel.com',       'Gold',    1),
    (4,  'Secretlab',            'Gaming Furniture', 'https://secretlab.co',      'b2b@secretlab.co',        'Silver',  1),
    (5,  'Monster Energy',       'Energy Drink',    'https://monsterenergy.com',  'events@monster.com',      'Silver',  1),
    (6,  'HyperX',               'Gaming Hardware',  'https://hyperx.com',        'esports@hyperx.com',      'Gold',    1),
    (7,  'Fnatic Gear',          'Gaming Peripherals','https://fnatic.com',        'sponsor@fnatic.com',      'Bronze',  1),
    (8,  'MTN South Africa',     'Telecom',          'https://mtn.co.za',         'esports@mtn.co.za',       'Silver',  1),
    (9,  'Vodacom',              'Telecom',          'https://vodacom.co.za',     'sponsorships@vodacom.co.za','Silver',  1),
    (10, 'Riot Games',           'Game Publisher',   'https://riotgames.com',     'esports@riotgames.com',   'Title',   1);

SET IDENTITY_INSERT ops.sponsor OFF;
GO

-- =============================================================================
-- ops.sponsorship
-- =============================================================================

SET IDENTITY_INSERT ops.sponsorship ON;

INSERT INTO ops.sponsorship
    (sponsorship_id, sponsor_id, team_id, tournament_id, deal_value, currency,
     start_date, end_date, visibility_type, status)
VALUES
    -- Title sponsors for tournaments
    (1,  1,  NULL, 3,  150000.00, 'USD', '2025-01-01', '2025-12-31', 'Title',      'Active'),
    (2,  10, NULL, 12, 800000.00, 'USD', '2025-01-01', '2025-12-31', 'Title',      'Active'),

    -- Team jerseys and branding
    (3,  2,  1,  NULL, 24000.00,  'USD', '2025-01-01', '2025-12-31', 'Jersey',     'Active'),
    (4,  6,  11, NULL, 36000.00,  'USD', '2025-01-01', '2025-12-31', 'Jersey',     'Active'),
    (5,  3,  17, NULL, 48000.00,  'USD', '2025-01-01', '2025-12-31', 'Jersey',     'Active'),
    (6,  2,  4,  NULL, 30000.00,  'USD', '2025-01-01', '2025-12-31', 'Jersey',     'Active'),

    -- SA regional sponsors
    (7,  8,  3,  NULL, 18000.00,  'USD', '2025-01-01', '2025-12-31', 'Jersey',     'Active'),
    (8,  9,  12, NULL, 15000.00,  'USD', '2025-01-01', '2025-12-31', 'Digital',    'Active'),
    (9,  8,  NULL, 6,  12000.00,  'USD', '2025-01-01', '2025-12-31', 'Banner',     'Active'),

    -- Banner and broadcast deals
    (10, 4,  NULL, 12, 60000.00,  'USD', '2025-06-01', '2025-12-31', 'Banner',     'Active'),
    (11, 5,  NULL, 3,  40000.00,  'USD', '2025-06-01', '2025-12-31', 'Broadcast',  'Active'),
    (12, 3,  NULL, 16, 200000.00, 'USD', '2025-08-01', '2025-12-31', 'Naming Rights','Active'),

    -- Expired deals for history
    (13, 7,  1,  NULL, 12000.00,  'USD', '2024-01-01', '2024-12-31', 'Digital',    'Expired'),
    (14, 5,  2,  NULL, 20000.00,  'USD', '2024-01-01', '2024-12-31', 'Jersey',     'Expired');

SET IDENTITY_INSERT ops.sponsorship OFF;
GO

PRINT '05_seed_business.sql: venue (5), event (8), ticket_tier (16), fan (25), ticket_order (23), sponsor (10), sponsorship (14) seeded.';
GO
