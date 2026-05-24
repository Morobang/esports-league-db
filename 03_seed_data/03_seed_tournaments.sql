-- =============================================================================
-- FILE:    03_seed_tournaments.sql
-- PURPOSE: Seed tournaments and team registrations
-- DEPENDS: 02_seed_teams_players.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.tournament  (16 tournaments across the leagues)
-- =============================================================================

SET IDENTITY_INSERT comp.tournament ON;

INSERT INTO comp.tournament
    (tournament_id, league_id, name, format, prize_pool, currency, start_date, end_date, is_lan, status)
VALUES
    -- Tekken World Tour EMEA (league 1)
    (1,  1, 'TWR EMEA Spring Split',       'Round-Robin',  10000.00, 'USD', '2025-01-15', '2025-03-30', 0, 'Completed'),
    (2,  1, 'TWR EMEA Summer Split',       'Round-Robin',  10000.00, 'USD', '2025-04-15', '2025-06-30', 0, 'Completed'),
    (3,  1, 'TWR EMEA Grand Finals',       'Double-Elim',  50000.00, 'USD', '2025-09-20', '2025-09-22', 1, 'Completed'),

    -- Tekken World Tour NA (league 2)
    (4,  2, 'TWR NA Spring Split',         'Round-Robin',  10000.00, 'USD', '2025-01-20', '2025-04-05', 0, 'Completed'),
    (5,  2, 'TWR NA Championships',        'Double-Elim',  30000.00, 'USD', '2025-07-10', '2025-07-12', 1, 'Completed'),

    -- Tekken SA Regional (league 3)
    (6,  3, 'SA Tekken Open Q1',           'Single-Elim',   3000.00, 'USD', '2025-02-15', '2025-02-16', 0, 'Completed'),
    (7,  3, 'SA Tekken Open Q2',           'Single-Elim',   3000.00, 'USD', '2025-05-10', '2025-05-11', 0, 'Completed'),

    -- KOF XV East Asia (league 4)
    (8,  4, 'KOF EA League Stage',         'Round-Robin',  15000.00, 'USD', '2025-03-01', '2025-06-28', 0, 'Completed'),
    (9,  4, 'KOF EA Playoffs',             'Single-Elim',  40000.00, 'USD', '2025-08-15', '2025-08-17', 1, 'Completed'),

    -- VCT EMEA (league 8)
    (10, 8, 'VCT EMEA Stage 1',           'Swiss',         80000.00, 'USD', '2025-01-20', '2025-03-16', 0, 'Completed'),
    (11, 8, 'VCT EMEA Stage 2',           'Swiss',         80000.00, 'USD', '2025-04-07', '2025-06-08', 0, 'Completed'),
    (12, 8, 'VCT EMEA Playoffs',          'Double-Elim',  200000.00, 'USD', '2025-08-01', '2025-08-10', 1, 'Completed'),

    -- VCT Game Changers SA (league 9)
    (13, 9, 'VCT GC SA Open Series',      'Round-Robin',   5000.00, 'USD', '2025-02-10', '2025-04-20', 0, 'Completed'),

    -- LEC Spring 2025 (league 10)
    (14, 10,'LEC Spring 2025 Season',     'Round-Robin',  500000.00, 'USD', '2025-01-12', '2025-03-09', 0, 'Completed'),
    (15, 10,'LEC Spring 2025 Playoffs',   'Double-Elim',  250000.00, 'USD', '2025-03-14', '2025-04-06', 1, 'Completed'),

    -- ESL Pro League S21 (league 12)
    (16, 12,'ESL Pro League S21',         'Round-Robin',  750000.00, 'USD', '2025-09-01', '2025-10-20', 1, 'Ongoing');

SET IDENTITY_INSERT comp.tournament OFF;
GO

-- =============================================================================
-- comp.tournament_team  (team registrations with seeds and placements)
-- =============================================================================

INSERT INTO comp.tournament_team (tournament_id, team_id, seed, final_placement, is_eliminated)
VALUES
    -- TWR EMEA Spring Split (tournament 1) — teams 1,3,5,6,17,20
    (1,  1,  2, 1, 1),   -- Echo Force      → 1st
    (1,  5,  1, 2, 1),   -- Vortex United   → 2nd
    (1,  3,  5, 3, 1),   -- Savanna         → 3rd
    (1,  6,  3, 4, 1),   -- Phantom SEA     → 4th
    (1,  17, 4, 5, 1),
    (1,  20, 6, 6, 1),

    -- TWR EMEA Summer Split (tournament 2)
    (2,  1,  1, 2, 1),
    (2,  5,  2, 1, 1),   -- Vortex United wins
    (2,  3,  4, 4, 1),
    (2,  6,  3, 3, 1),
    (2,  17, 5, 5, 1),
    (2,  20, 6, 6, 1),

    -- TWR EMEA Grand Finals (tournament 3) — top 4 qualify
    (3,  1,  2, 1, 1),   -- Echo Force wins Grand Finals
    (3,  5,  1, 2, 1),
    (3,  6,  3, 3, 1),
    (3,  3,  4, 4, 1),

    -- TWR NA Spring Split (tournament 4) — teams 2,8,13,16
    (4,  2,  1, 1, 1),   -- Iron Pulse Gaming wins
    (4,  8,  3, 3, 1),
    (4,  13, 4, 4, 1),
    (4,  16, 2, 2, 1),

    -- TWR NA Championships (tournament 5)
    (5,  2,  1, 1, 1),
    (5,  16, 2, 2, 1),
    (5,  8,  3, 3, 1),
    (5,  13, 4, 4, 1),

    -- SA Tekken Open Q1 (tournament 6) — SA teams
    (6,  3,  1, 1, 1),   -- Savanna wins
    (6,  12, 2, 2, 1),
    (6,  19, 3, 3, 1),

    -- SA Tekken Open Q2 (tournament 7)
    (7,  3,  1, 2, 1),
    (7,  12, 2, 1, 1),   -- Ubuntu Squad wins
    (7,  19, 3, 3, 1),

    -- KOF EA League Stage (tournament 8)
    (8,  4,  1, 1, 1),   -- Sakura Storm
    (8,  6,  2, 2, 1),
    (8,  10, 3, 3, 1),
    (8,  14, 4, 4, 1),

    -- KOF EA Playoffs (tournament 9)
    (9,  4,  1, 1, 1),
    (9,  6,  2, 2, 1),
    (9,  10, 3, 3, 1),
    (9,  14, 4, 4, 1),

    -- VCT EMEA Stage 1 (tournament 10)
    (10, 11, 1, 2, 1),
    (10, 13, 3, 4, 1),
    (10, 14, 4, 3, 1),
    (10, 17, 2, 1, 1),   -- Cipher Esports wins Stage 1

    -- VCT EMEA Stage 2 (tournament 11)
    (11, 11, 2, 1, 1),   -- Apex Protocol wins Stage 2
    (11, 13, 3, 3, 1),
    (11, 14, 4, 4, 1),
    (11, 17, 1, 2, 1),

    -- VCT EMEA Playoffs (tournament 12)
    (12, 11, 2, 1, 1),   -- Apex Protocol wins
    (12, 17, 1, 2, 1),
    (12, 14, 4, 3, 1),
    (12, 13, 3, 4, 1),

    -- VCT GC SA (tournament 13)
    (13, 12, 1, 1, 1),   -- Ubuntu Squad wins
    (13, 19, 2, 2, 1),

    -- LEC Spring Season (tournament 14)
    (14, 15, 1, 2, 1),
    (14, 16, 2, 1, 1),   -- Redwood Gaming wins regular season

    -- LEC Spring Playoffs (tournament 15)
    (15, 15, 2, 1, 1),   -- Frost Giants win playoffs
    (15, 16, 1, 2, 1),

    -- ESL Pro League S21 (tournament 16 — ongoing)
    (16, 17, 1, NULL, 0),
    (16, 18, 2, NULL, 0),
    (16, 20, 3, NULL, 0);
GO

PRINT '03_seed_tournaments.sql: tournament (16), tournament_team (57) seeded.';
GO
