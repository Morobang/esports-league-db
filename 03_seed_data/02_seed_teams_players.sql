-- =============================================================================
-- FILE:    02_seed_teams_players.sql
-- PURPOSE: Seed leagues, teams, players, coaching staff, and contracts
-- DEPENDS: 01_seed_reference.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.league  (12 leagues across 4 games and multiple regions)
-- =============================================================================

SET IDENTITY_INSERT comp.league ON;

INSERT INTO comp.league (league_id, game_id, region_id, name, tier, season, start_date, end_date, is_active)
VALUES
    -- Tekken 8
    (1,  1, 2, 'Tekken World Tour EMEA',         'Tier1', 'S2025', '2025-01-15', '2025-12-15', 1),
    (2,  1, 1, 'Tekken World Tour NA',            'Tier1', 'S2025', '2025-01-15', '2025-12-15', 1),
    (3,  1, 3, 'Tekken SA Regional Circuit',      'Tier2', 'S2025', '2025-02-01', '2025-11-30', 1),
    -- KOF XV
    (4,  2, 5, 'KOF XV East Asia League',         'Tier1', 'S2025', '2025-03-01', '2025-11-01', 1),
    (5,  2, 2, 'KOF XV EMEA Open',               'Tier2', 'S2025', '2025-03-15', '2025-10-15', 1),
    -- FC 26
    (6,  3, 2, 'EA Sports FC Pro EMEA',           'Tier1', 'S2025', '2025-08-01', '2026-05-31', 1),
    (7,  3, 1, 'EA Sports FC Pro NA',             'Tier1', 'S2025', '2025-08-01', '2026-05-31', 1),
    -- Valorant
    (8,  5, 2, 'VCT EMEA',                        'Tier1', 'S2025', '2025-01-20', '2025-11-30', 1),
    (9,  5, 3, 'VCT Game Changers SA',            'Tier2', 'S2025', '2025-02-10', '2025-10-10', 1),
    -- League of Legends
    (10, 6, 2, 'LEC Spring 2025',                 'Tier1', 'S2025', '2025-01-12', '2025-04-06', 0),
    (11, 6, 1, 'LCS Spring 2025',                 'Tier1', 'S2025', '2025-01-11', '2025-04-05', 0),
    -- CS2
    (12, 7, 2, 'ESL Pro League Season 21',        'Tier1', 'S2025', '2025-09-01', '2025-10-20', 1);

SET IDENTITY_INSERT comp.league OFF;
GO

-- =============================================================================
-- comp.team  (20 teams)
-- =============================================================================

SET IDENTITY_INSERT comp.team ON;

INSERT INTO comp.team (team_id, region_id, name, tag, logo_url, founded_at, is_active)
VALUES
    -- Fighting game orgs
    (1,  2, 'Echo Force',           'EF',   NULL, '2019-03-10', 1),
    (2,  1, 'Iron Pulse Gaming',    'IPG',  NULL, '2018-07-22', 1),
    (3,  3, 'Savanna Esports',      'SVN',  NULL, '2021-05-01', 1),
    (4,  5, 'Sakura Storm',         'SKS',  NULL, '2017-11-14', 1),
    (5,  2, 'Vortex United',        'VTX',  NULL, '2020-02-28', 1),
    (6,  4, 'Phantom SEA',          'PHM',  NULL, '2019-09-05', 1),
    -- FC orgs
    (7,  2, 'Digital FC',           'DFC',  NULL, '2022-06-15', 1),
    (8,  1, 'Grid Lions',           'GRL',  NULL, '2021-01-20', 1),
    (9,  6, 'Amazonia FC',          'AMZ',  NULL, '2020-08-11', 1),
    (10, 5, 'Neon Strikers',        'NST',  NULL, '2022-03-03', 1),
    -- Valorant orgs
    (11, 2, 'Apex Protocol',        'APX',  NULL, '2020-10-01', 1),
    (12, 3, 'Ubuntu Squad',         'UBT',  NULL, '2022-01-15', 1),
    (13, 1, 'Static Rush',          'STR',  NULL, '2019-04-17', 1),
    (14, 4, 'Typhoon Esports',      'TYP',  NULL, '2018-12-01', 1),
    -- LoL orgs
    (15, 2, 'Frost Giants GG',      'FGG',  NULL, '2017-05-20', 1),
    (16, 1, 'Redwood Gaming',       'RWG',  NULL, '2016-09-08', 1),
    -- CS2 orgs
    (17, 2, 'Cipher Esports',       'CPH',  NULL, '2018-03-25', 1),
    (18, 1, 'Omega Protocol',       'OMP',  NULL, '2019-07-14', 1),
    (19, 3, 'Highveld Crew',        'HVC',  NULL, '2023-02-01', 1),
    (20, 8, 'Desert Hawks',         'DHK',  NULL, '2021-11-30', 1);

SET IDENTITY_INSERT comp.team OFF;
GO

-- =============================================================================
-- comp.player  (60 players across the 20 teams)
-- =============================================================================

SET IDENTITY_INSERT comp.player ON;

INSERT INTO comp.player (player_id, team_id, username, real_name, nationality, role, status, joined_at, left_at)
VALUES
    -- Echo Force (team 1) — Fighting game
    (1,  1, 'RaijinX',      'Marco Ferreira',    'Portuguese',    'Main',     'Active', '2022-01-10', NULL),
    (2,  1, 'ColdSnap',     'Lena Brandt',        'German',        'Support',  'Active', '2023-03-15', NULL),
    (3,  1, 'VoltEdge',     'Yusuf Al-Farsi',     'Emirati',       'Main',     'Active', '2021-11-01', NULL),
    (4,  1, 'PhantomKick',  'Sofia Petrov',       'Bulgarian',     'Reserve',  'Active', '2024-01-20', NULL),

    -- Iron Pulse Gaming (team 2)
    (5,  2, 'NightHawk',    'Darius Cole',        'American',      'Main',     'Active', '2020-06-01', NULL),
    (6,  2, 'Reckless99',   'Jaylen Moore',       'American',      'Main',     'Active', '2021-02-14', NULL),
    (7,  2, 'IronFist',     'Carlos Mendez',      'Mexican',       'Support',  'Active', '2022-08-09', NULL),
    (8,  2, 'GlitchKing',   'Tommy Zhang',        'Canadian',      'Reserve',  'Active', '2023-05-22', NULL),

    -- Savanna Esports (team 3)
    (9,  3, 'Predator_ZA',  'Thabo Dlamini',      'South African', 'Main',     'Active', '2021-05-10', NULL),
    (10, 3, 'KhoiKing',     'Sipho Khumalo',      'South African', 'Main',     'Active', '2022-02-28', NULL),
    (11, 3, 'FireStarter',  'Amara Osei',         'Ghanaian',      'Support',  'Active', '2023-07-01', NULL),
    (12, 3, 'ZuluWarrior',  'Nhlanhla Zulu',      'South African', 'Reserve',  'Active', '2024-03-15', NULL),

    -- Sakura Storm (team 4)
    (13, 4, 'TempestBlade', 'Hiro Tanaka',        'Japanese',      'Main',     'Active', '2019-04-01', NULL),
    (14, 4, 'SilverWind',   'Yuki Sato',          'Japanese',      'Main',     'Active', '2020-09-15', NULL),
    (15, 4, 'KiryuStrike',  'Kenji Mori',         'Japanese',      'Support',  'Active', '2021-12-01', NULL),
    (16, 4, 'NeonKatana',   'Riku Hayashi',       'Japanese',      'Reserve',  'Active', '2023-03-10', NULL),

    -- Vortex United (team 5)
    (17, 5, 'CycloneX',     'Pierre Dubois',      'French',        'Main',     'Active', '2020-07-20', NULL),
    (18, 5, 'StormRider',   'Ana Costa',          'Spanish',       'Main',     'Active', '2021-05-05', NULL),
    (19, 5, 'BladeRunner',  'Erik Hansen',        'Danish',        'Support',  'Active', '2022-11-30', NULL),
    (20, 5, 'NullVector',   'Klara Novak',        'Czech',         'Reserve',  'Active', '2023-08-14', NULL),

    -- Phantom SEA (team 6)
    (21, 6, 'GhostPulse',   'Wei Liang',          'Singaporean',   'Main',     'Active', '2021-01-15', NULL),
    (22, 6, 'DragonFang',   'Ahmad Rizal',        'Malaysian',     'Main',     'Active', '2020-11-01', NULL),
    (23, 6, 'SerpentKing',  'Paolo Santos',       'Filipino',      'Support',  'Active', '2022-04-22', NULL),
    (24, 6, 'TidalForce',   'Nattapong Saen',     'Thai',          'Reserve',  'Active', '2023-09-01', NULL),

    -- Digital FC (team 7)
    (25, 7, 'NetBuster',    'Finn O Brien',       'Irish',         'Main',     'Active', '2022-06-20', NULL),
    (26, 7, 'PixelStriker', 'Lukas Hofer',        'Austrian',      'Main',     'Active', '2023-01-10', NULL),
    (27, 7, 'ChipShot',     'Remy Laurent',       'French',        'Support',  'Active', '2022-09-05', NULL),
    (28, 7, 'DataDribble',  'Marco Russo',        'Italian',       'Reserve',  'Active', '2024-02-01', NULL),

    -- Grid Lions (team 8)
    (29, 8, 'LionKing',     'Malik Johnson',      'American',      'Main',     'Active', '2021-03-01', NULL),
    (30, 8, 'ClawBack',     'Devon Harris',       'Jamaican',      'Main',     'Active', '2022-07-15', NULL),
    (31, 8, 'GridMaster',   'Chase Miller',       'American',      'Support',  'Active', '2023-04-10', NULL),
    (32, 8, 'PackHunter',   'Elijah Brooks',      'American',      'Reserve',  'Active', '2024-01-05', NULL),

    -- Amazonia FC (team 9)
    (33, 9, 'JaguarRun',    'Rafael Silva',       'Brazilian',     'Main',     'Active', '2020-09-01', NULL),
    (34, 9, 'RiverFlow',    'Diego Pereira',      'Brazilian',     'Main',     'Active', '2021-11-20', NULL),
    (35, 9, 'TropicStrike', 'Mateus Lima',        'Brazilian',     'Support',  'Active', '2022-06-05', NULL),
    (36, 9, 'CanopyDash',   'Fernando Costa',     'Brazilian',     'Reserve',  'Active', '2023-10-14', NULL),

    -- Neon Strikers (team 10)
    (37, 10,'NeonBlaze',    'Ren Nakamura',       'Japanese',      'Main',     'Active', '2022-04-01', NULL),
    (38, 10,'LaserFoot',    'Sho Kimura',         'Japanese',      'Main',     'Active', '2022-10-15', NULL),
    (39, 10,'PulseKick',    'Daiki Yamamoto',     'Japanese',      'Support',  'Active', '2023-02-28', NULL),
    (40, 10,'GridFlash',    'Yuto Abe',           'Japanese',      'Reserve',  'Active', '2024-03-01', NULL),

    -- Apex Protocol (team 11)
    (41, 11,'ApexHunter',   'Nathan Clarke',      'British',       'IGL',      'Active', '2020-12-01', NULL),
    (42, 11,'SignalFire',   'Isabelle Morel',     'French',        'Duelist',  'Active', '2021-08-20', NULL),
    (43, 11,'Sentinel_APX', 'Viktor Sobol',       'Ukrainian',     'Sentinel', 'Active', '2022-05-10', NULL),
    (44, 11,'FlashCode',    'Asel Nurova',        'Kazakh',        'Initiator','Active', '2023-01-30', NULL),
    (45, 11,'WireFrame',    'Tobias Hein',        'German',        'Controller','Active','2021-03-15', NULL),

    -- Ubuntu Squad (team 12)
    (46, 12,'UbuntuIGL',    'Lungelo Dube',       'South African', 'IGL',      'Active', '2022-02-01', NULL),
    (47, 12,'KilimanShot',  'Baraka Mwangi',      'Kenyan',        'Duelist',  'Active', '2022-06-10', NULL),
    (48, 12,'SahelSnipe',   'Oumar Diallo',       'Senegalese',    'Sentinel', 'Active', '2023-03-20', NULL),
    (49, 12,'NileFlash',    'Amira Hassan',       'Egyptian',      'Initiator','Active', '2023-09-01', NULL),
    (50, 12,'CapeSurge',    'Zandile Nkosi',      'South African', 'Controller','Active','2022-11-15', NULL),

    -- Static Rush (team 13)
    (51, 13,'StaticIGL',    'Tyler Brooks',       'American',      'IGL',      'Active', '2019-05-01', NULL),
    (52, 13,'VoltDash',     'Maya Chen',          'American',      'Duelist',  'Active', '2020-11-10', NULL),
    (53, 13,'HeatSeek',     'Jordan Webb',        'Canadian',      'Sentinel', 'Active', '2021-07-22', NULL),
    (54, 13,'PulseNode',    'Ravi Patel',         'Indian-American','Initiator','Active','2022-04-05', NULL),
    (55, 13,'FreqDrop',     'Layla Kim',          'Korean-American','Controller','Active','2023-02-18', NULL),

    -- Frost Giants GG (team 15) — LoL
    (56, 15,'FrostJungler', 'Aleksander Dahl',    'Norwegian',     'Jungle',   'Active', '2021-01-10', NULL),
    (57, 15,'IceMid',       'Chen Wei',           'Chinese',       'Mid',      'Active', '2020-08-01', NULL),
    (58, 15,'GlacialADC',   'Sofie Lund',         'Danish',        'ADC',      'Active', '2022-03-14', NULL),

    -- Cipher Esports (team 17) — CS2
    (59, 17,'CipherIGL',    'Niklas Bauer',       'German',        'IGL',      'Active', '2018-05-01', NULL),
    (60, 17,'HeadshotH',    'Jakub Novotny',      'Czech',         'AWPer',    'Active', '2019-11-20', NULL);

SET IDENTITY_INSERT comp.player OFF;
GO

-- =============================================================================
-- comp.staff  (coaching staff for 10 teams)
-- =============================================================================

SET IDENTITY_INSERT comp.staff ON;

INSERT INTO comp.staff (staff_id, team_id, full_name, role, nationality, joined_at, left_at)
VALUES
    (1,  1,  'Mikael Johansson',  'Head Coach',    'Swedish',       '2021-01-01', NULL),
    (2,  1,  'Patricia Gomez',    'Analyst',       'Spanish',       '2022-06-01', NULL),
    (3,  2,  'Ray Thompson',      'Head Coach',    'American',      '2020-03-15', NULL),
    (4,  2,  'Chris Park',        'Team Manager',  'Korean-American','2021-09-01', NULL),
    (5,  3,  'Siphamandla Moyo',  'Head Coach',    'South African', '2021-05-10', NULL),
    (6,  3,  'Thandi Ngcobo',     'Analyst',       'South African', '2022-10-01', NULL),
    (7,  4,  'Masato Inoue',      'Head Coach',    'Japanese',      '2019-01-15', NULL),
    (8,  5,  'Jerome Blanc',      'Head Coach',    'French',        '2020-09-01', NULL),
    (9,  11, 'Gareth Owen',       'Head Coach',    'Welsh',         '2021-01-20', NULL),
    (10, 11, 'Nina Schwarz',      'Analyst',       'German',        '2022-04-10', NULL),
    (11, 12, 'Olumide Fashola',   'Head Coach',    'Nigerian',      '2022-03-01', NULL),
    (12, 17, 'Bernhard Kraus',    'Head Coach',    'Austrian',      '2018-07-01', NULL),
    (13, 17, 'Petra Volkov',      'Analyst',       'Russian',       '2020-02-15', NULL),
    (14, 15, 'Lars Eriksson',     'Head Coach',    'Swedish',       '2020-05-01', NULL),
    (15, 8,  'Marcus Reid',       'Head Coach',    'British',       '2021-04-01', NULL);

SET IDENTITY_INSERT comp.staff OFF;
GO

-- =============================================================================
-- comp.contract  (active contracts — one per active player where applicable)
-- =============================================================================

SET IDENTITY_INSERT comp.contract ON;

INSERT INTO comp.contract
    (contract_id, player_id, team_id, salary_monthly, currency, start_date, end_date, status, buyout_clause)
VALUES
    (1,  1,  1,  3500.00,  'USD', '2022-01-10', '2025-12-31', 'Active',  15000.00),
    (2,  2,  1,  2800.00,  'USD', '2023-03-15', '2025-12-31', 'Active',  10000.00),
    (3,  3,  1,  4200.00,  'USD', '2021-11-01', '2025-10-31', 'Active',  20000.00),
    (4,  5,  2,  5000.00,  'USD', '2020-06-01', '2025-05-31', 'Active',  25000.00),
    (5,  6,  2,  4500.00,  'USD', '2021-02-14', '2025-02-13', 'Active',  18000.00),
    (6,  9,  3,  1800.00,  'USD', '2021-05-10', '2025-05-09', 'Active',   8000.00),
    (7,  10, 3,  1600.00,  'USD', '2022-02-28', '2025-12-31', 'Active',   6000.00),
    (8,  13, 4,  6000.00,  'USD', '2019-04-01', '2025-03-31', 'Active',  30000.00),
    (9,  14, 4,  5500.00,  'USD', '2020-09-15', '2025-09-14', 'Active',  22000.00),
    (10, 17, 5,  4000.00,  'USD', '2020-07-20', '2025-07-19', 'Active',  16000.00),
    (11, 41, 11, 7500.00,  'USD', '2020-12-01', '2025-11-30', 'Active',  35000.00),
    (12, 42, 11, 6800.00,  'USD', '2021-08-20', '2025-08-19', 'Active',  28000.00),
    (13, 45, 11, 6200.00,  'USD', '2021-03-15', '2025-03-14', 'Active',  25000.00),
    (14, 46, 12, 2200.00,  'USD', '2022-02-01', '2025-12-31', 'Active',   9000.00),
    (15, 51, 13, 8000.00,  'USD', '2019-05-01', '2025-04-30', 'Active',  40000.00),
    (16, 59, 17, 9500.00,  'USD', '2018-05-01', '2025-04-30', 'Active',  50000.00),
    (17, 60, 17, 8800.00,  'USD', '2019-11-20', '2025-11-19', 'Active',  45000.00),
    -- Historical expired contracts
    (18, 5,  2,  3800.00,  'USD', '2018-01-01', '2020-05-31', 'Expired', NULL),
    (19, 13, 4,  4500.00,  'USD', '2017-06-01', '2019-03-31', 'Expired', NULL),
    (20, 41, 11, 5500.00,  'USD', '2019-01-01', '2020-11-30', 'Expired', NULL);

SET IDENTITY_INSERT comp.contract OFF;
GO

PRINT '02_seed_teams_players.sql: league (12), team (20), player (60), staff (15), contract (20) seeded.';
GO
