-- =============================================================================
-- FILE:    01_seed_reference.sql
-- PURPOSE: Seed reference/lookup tables — game and region
-- DEPENDS: 01_schema/02_core_competition.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.game
-- =============================================================================

SET IDENTITY_INSERT comp.game ON;

INSERT INTO comp.game (game_id, name, genre, publisher, platform, is_active)
VALUES
    (1,  'Tekken 8',                    'Fighting',          'Bandai Namco',     'Cross-platform', 1),
    (2,  'The King of Fighters XV',     'Fighting',          'SNK',              'Cross-platform', 1),
    (3,  'EA Sports FC 26',             'Sports Simulation', 'EA Sports',        'Cross-platform', 1),
    (4,  'Street Fighter 6',            'Fighting',          'Capcom',           'Cross-platform', 1),
    (5,  'Valorant',                    'Tactical Shooter',  'Riot Games',       'PC',             1),
    (6,  'League of Legends',           'MOBA',              'Riot Games',       'PC',             1),
    (7,  'Counter-Strike 2',            'Tactical Shooter',  'Valve',            'PC',             1),
    (8,  'Mortal Kombat 1',             'Fighting',          'NetherRealm',      'Cross-platform', 1),
    (9,  'Rocket League',               'Sports Simulation', 'Psyonix',          'Cross-platform', 1),
    (10, 'Elden Ring PvP Circuit',      'Action RPG',        'FromSoftware',     'Cross-platform', 0);

SET IDENTITY_INSERT comp.game OFF;
GO

-- =============================================================================
-- comp.region
-- =============================================================================

SET IDENTITY_INSERT comp.region ON;

INSERT INTO comp.region (region_id, name, code, timezone)
VALUES
    (1,  'North America',           'NA',   'America/New_York'),
    (2,  'Europe, Middle East & Africa', 'EMEA', 'Europe/London'),
    (3,  'South Africa',            'ZA',   'Africa/Johannesburg'),
    (4,  'South East Asia',         'SEA',  'Asia/Singapore'),
    (5,  'East Asia',               'EA',   'Asia/Tokyo'),
    (6,  'Latin America',           'LATAM','America/Sao_Paulo'),
    (7,  'Oceania',                 'OCE',  'Australia/Sydney'),
    (8,  'Middle East & North Africa','MENA','Asia/Dubai');

SET IDENTITY_INSERT comp.region OFF;
GO

PRINT '01_seed_reference.sql: game (10 rows), region (8 rows) seeded.';
GO
