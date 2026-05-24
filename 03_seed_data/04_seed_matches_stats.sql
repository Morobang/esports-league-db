-- =============================================================================
-- FILE:    04_seed_matches_stats.sql
-- PURPOSE: Seed matches, map results, player stats, player ratings, standings
-- DEPENDS: 03_seed_tournaments.sql
-- NOTE:    Focused on tournaments 1, 3, 10, 12 for dense query optimisation data
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.match
-- =============================================================================

SET IDENTITY_INSERT comp.match ON;

INSERT INTO comp.match
    (match_id, tournament_id, team_a_id, team_b_id, winner_id, score_a, score_b,
     stage, best_of, status, played_at)
VALUES
    -- TWR EMEA Spring Split (tournament 1) — Round Robin matches
    (1,  1, 1,  5,  1,  2, 0, 'Group Stage', 3, 'Completed', '2025-01-20 14:00:00'),
    (2,  1, 1,  6,  1,  2, 1, 'Group Stage', 3, 'Completed', '2025-01-27 14:00:00'),
    (3,  1, 5,  6,  5,  2, 0, 'Group Stage', 3, 'Completed', '2025-02-03 14:00:00'),
    (4,  1, 1,  3,  1,  2, 0, 'Group Stage', 3, 'Completed', '2025-02-10 14:00:00'),
    (5,  1, 5,  3,  5,  2, 1, 'Group Stage', 3, 'Completed', '2025-02-17 14:00:00'),
    (6,  1, 6,  3,  3,  1, 2, 'Group Stage', 3, 'Completed', '2025-02-24 14:00:00'),
    (7,  1, 1,  17, 1,  2, 0, 'Group Stage', 3, 'Completed', '2025-03-03 14:00:00'),
    (8,  1, 5,  17, 5,  2, 1, 'Group Stage', 3, 'Completed', '2025-03-10 14:00:00'),
    (9,  1, 1,  20, 1,  2, 0, 'Group Stage', 3, 'Completed', '2025-03-17 14:00:00'),
    (10, 1, 5,  20, 5,  2, 0, 'Group Stage', 3, 'Completed', '2025-03-24 14:00:00'),

    -- TWR EMEA Grand Finals (tournament 3) — Double Elim
    (11, 3, 1,  5,  1,  3, 2, 'Semi-Final',  5, 'Completed', '2025-09-20 16:00:00'),
    (12, 3, 6,  3,  6,  3, 1, 'Semi-Final',  5, 'Completed', '2025-09-20 19:00:00'),
    (13, 3, 1,  6,  1,  3, 0, 'GrandFinal',  5, 'Completed', '2025-09-22 17:00:00'),

    -- VCT EMEA Stage 1 (tournament 10) — Swiss
    (14, 10, 11, 13, 11, 2, 0, 'Group Stage', 3, 'Completed', '2025-01-20 15:00:00'),
    (15, 10, 17, 14, 17, 2, 1, 'Group Stage', 3, 'Completed', '2025-01-21 15:00:00'),
    (16, 10, 11, 14, 14, 1, 2, 'Group Stage', 3, 'Completed', '2025-02-03 15:00:00'),
    (17, 10, 17, 13, 17, 2, 0, 'Group Stage', 3, 'Completed', '2025-02-04 15:00:00'),
    (18, 10, 11, 17, 17, 0, 2, 'Group Stage', 3, 'Completed', '2025-02-17 15:00:00'),
    (19, 10, 14, 13, 14, 2, 1, 'Group Stage', 3, 'Completed', '2025-02-18 15:00:00'),
    (20, 10, 17, 11, 17, 2, 1, 'Quarter-Final',3,'Completed', '2025-03-10 16:00:00'),
    (21, 10, 14, 13, 14, 2, 0, 'Quarter-Final',3,'Completed', '2025-03-10 19:00:00'),
    (22, 10, 17, 14, 17, 2, 1, 'Semi-Final',  5, 'Completed', '2025-03-14 17:00:00'),

    -- VCT EMEA Playoffs (tournament 12) — Double Elim
    (23, 12, 11, 17, 11, 3, 1, 'Upper-Bracket', 5, 'Completed', '2025-08-01 16:00:00'),
    (24, 12, 14, 13, 14, 3, 2, 'Lower-Bracket', 5, 'Completed', '2025-08-02 16:00:00'),
    (25, 12, 11, 14, 11, 3, 0, 'GrandFinal',    5, 'Completed', '2025-08-10 17:00:00'),

    -- TWR NA Spring Split (tournament 4)
    (26, 4, 2,  16, 2,  2, 1, 'Group Stage', 3, 'Completed', '2025-01-22 18:00:00'),
    (27, 4, 2,  8,  2,  2, 0, 'Group Stage', 3, 'Completed', '2025-02-05 18:00:00'),
    (28, 4, 16, 13, 16, 2, 0, 'Group Stage', 3, 'Completed', '2025-02-19 18:00:00'),
    (29, 4, 2,  13, 2,  2, 1, 'Semi-Final',  3, 'Completed', '2025-03-15 18:00:00'),
    (30, 4, 16, 8,  16, 2, 0, 'Semi-Final',  3, 'Completed', '2025-03-15 21:00:00'),
    (31, 4, 2,  16, 2,  2, 0, 'Final',       3, 'Completed', '2025-04-05 18:00:00');

SET IDENTITY_INSERT comp.match OFF;
GO

-- =============================================================================
-- comp.match_map  (map-level results for key matches)
-- =============================================================================

SET IDENTITY_INSERT comp.match_map ON;

INSERT INTO comp.match_map
    (map_id, match_id, map_number, map_name, team_a_score, team_b_score, duration_min, played_at)
VALUES
    -- match 1  (EF vs VTX, EF wins 2-0)
    (1,  1, 1, 'Mishima Dojo',    13, 8,  42, '2025-01-20 14:00:00'),
    (2,  1, 2, 'Forgotten Realm', 13, 7,  38, '2025-01-20 14:45:00'),

    -- match 11 (EF vs VTX Bo5 semi-final, 3-2)
    (3,  11, 1, 'Mishima Dojo',    13, 10, 48, '2025-09-20 16:00:00'),
    (4,  11, 2, 'Forgotten Realm',  8, 13, 44, '2025-09-20 16:55:00'),
    (5,  11, 3, 'Arena Stage',     13,  9, 41, '2025-09-20 17:45:00'),
    (6,  11, 4, 'King of Iron',     9, 13, 50, '2025-09-20 18:40:00'),
    (7,  11, 5, 'Blood Talon',     13, 11, 55, '2025-09-20 19:40:00'),

    -- match 13 (EF vs PHM Grand Final, 3-0)
    (8,  13, 1, 'Mishima Dojo',    13,  5, 35, '2025-09-22 17:00:00'),
    (9,  13, 2, 'Arena Stage',     13,  8, 40, '2025-09-22 17:40:00'),
    (10, 13, 3, 'Blood Talon',     13,  6, 37, '2025-09-22 18:25:00'),

    -- match 23 (APX vs CPH VCT Bo5)
    (11, 23, 1, 'Ascent',          13, 11, 52, '2025-08-01 16:00:00'),
    (12, 23, 2, 'Bind',            10, 13, 49, '2025-08-01 16:58:00'),
    (13, 23, 3, 'Haven',           13,  8, 44, '2025-08-01 17:53:00'),
    (14, 23, 4, 'Lotus',            9, 13, 58, '2025-08-01 18:57:00'),
    (15, 23, 5, 'Pearl',           13, 11, 63, '2025-08-01 20:05:00'),

    -- match 25 (APX vs TYP Grand Final, 3-0)
    (16, 25, 1, 'Ascent',          13,  7, 38, '2025-08-10 17:00:00'),
    (17, 25, 2, 'Haven',           13,  9, 43, '2025-08-10 17:43:00'),
    (18, 25, 3, 'Icebox',          13, 10, 47, '2025-08-10 18:33:00');

SET IDENTITY_INSERT comp.match_map OFF;
GO

-- =============================================================================
-- comp.player_stat  (stats for tournament 1 and 12 matches)
-- =============================================================================

SET IDENTITY_INSERT comp.player_stat ON;

INSERT INTO comp.player_stat
    (stat_id, match_id, player_id, kills, deaths, assists, damage_dealt, healing_done, first_blood, mvp_flag)
VALUES
    -- match 1: EF (players 1-4) vs VTX (players 17-20)
    (1,  1, 1,  18, 9,  6,  28400, 0,    1, 1),  -- RaijinX MVP
    (2,  1, 2,  12, 11, 9,  19200, 0,    0, 0),
    (3,  1, 3,  15, 8,  7,  24800, 0,    0, 0),
    (4,  1, 4,   6, 12, 4,  10400, 0,    0, 0),
    (5,  1, 17, 11, 14, 5,  17600, 0,    0, 0),
    (6,  1, 18,  9, 15, 6,  14200, 0,    0, 0),
    (7,  1, 19,  7, 13, 8,  12400, 0,    0, 0),
    (8,  1, 20,  4, 14, 3,   7800, 0,    0, 0),

    -- match 2: EF vs PHM
    (9,  2, 1,  22, 10, 8,  33600, 0,    1, 1),
    (10, 2, 2,  14, 12, 11, 21800, 0,    0, 0),
    (11, 2, 3,  17, 9,  9,  26200, 0,    0, 0),
    (12, 2, 4,   8, 13, 5,  12200, 0,    0, 0),
    (13, 2, 21, 10, 16, 6,  16200, 0,    0, 0),
    (14, 2, 22,  8, 17, 7,  13400, 0,    0, 0),

    -- match 13 (Grand Final): EF vs PHM
    (15, 13, 1,  35, 12, 14, 52400, 0,   1, 1),  -- RaijinX Grand Final MVP
    (16, 13, 2,  22, 15, 18, 33800, 0,   0, 0),
    (17, 13, 3,  28, 10, 16, 42600, 0,   0, 1),
    (18, 13, 4,  14, 18,  9, 22200, 0,   0, 0),
    (19, 13, 21, 14, 24,  8, 22800, 0,   0, 0),
    (20, 13, 22, 11, 26,  9, 18400, 0,   0, 0),
    (21, 13, 23,  9, 28, 11, 16200, 0,   0, 0),

    -- match 23 (VCT APX vs CPH Bo5)
    (22, 23, 41, 28, 22, 12, 58200, 1200, 1, 1), -- ApexHunter IGL MVP
    (23, 23, 42, 35, 19, 8,  71400, 0,    0, 0),
    (24, 23, 43, 22, 24, 16, 45200, 2100, 0, 0),
    (25, 23, 44, 18, 28, 21, 38400, 4200, 0, 0),
    (26, 23, 45, 14, 20, 24, 28800, 8600, 0, 0),
    (27, 23, 59, 30, 21, 10, 62800, 0,    0, 1),
    (28, 23, 60, 38, 16, 5,  79400, 0,    1, 0),

    -- match 25 (VCT Grand Final: APX vs TYP)
    (29, 25, 41, 32, 18, 15, 64400, 1800, 1, 1),
    (30, 25, 42, 44, 14, 9,  88200, 0,    0, 1),
    (31, 25, 43, 28, 20, 22, 57400, 3200, 0, 0),
    (32, 25, 44, 21, 25, 28, 44200, 6800, 0, 0),
    (33, 25, 45, 18, 17, 32, 37800,12400, 0, 0);

SET IDENTITY_INSERT comp.player_stat OFF;
GO

-- =============================================================================
-- comp.player_rating  (ELO snapshots post-tournament)
-- =============================================================================

SET IDENTITY_INSERT comp.player_rating ON;

INSERT INTO comp.player_rating
    (rating_id, player_id, tournament_id, elo_score, rank_position, games_played, win_rate, calculated_at)
VALUES
    -- Tournament 1 (TWR EMEA Spring)
    (1,  1,  1, 1285.50, 1,  10, 80.00, '2025-03-30 23:00:00'),
    (2,  3,  1, 1240.00, 2,  10, 70.00, '2025-03-30 23:00:00'),
    (3,  2,  1, 1180.25, 3,  10, 60.00, '2025-03-30 23:00:00'),
    (4,  17, 1, 1050.00, 4,   8, 37.50, '2025-03-30 23:00:00'),
    (5,  18, 1, 1010.75, 5,   8, 37.50, '2025-03-30 23:00:00'),

    -- Tournament 3 (TWR EMEA Grand Finals)
    (6,  1,  3, 1340.00, 1,  3, 100.00, '2025-09-22 21:00:00'),
    (7,  3,  3, 1295.50, 2,  3,  66.67, '2025-09-22 21:00:00'),
    (8,  17, 3, 1190.00, 3,  3,  33.33, '2025-09-22 21:00:00'),

    -- Tournament 12 (VCT EMEA Playoffs)
    (9,  41, 12, 1410.00, 1,  3, 100.00, '2025-08-10 22:00:00'),
    (10, 42, 12, 1380.50, 2,  3, 100.00, '2025-08-10 22:00:00'),
    (11, 43, 12, 1290.00, 3,  3, 100.00, '2025-08-10 22:00:00'),
    (12, 59, 12, 1250.75, 4,  3,  33.33, '2025-08-10 22:00:00'),
    (13, 60, 12, 1220.00, 5,  3,  33.33, '2025-08-10 22:00:00'),

    -- Tournament 10 (VCT EMEA Stage 1)
    (14, 41, 10, 1180.00, 2,  6,  50.00, '2025-03-16 22:00:00'),
    (15, 59, 10, 1220.50, 1,  6,  83.33, '2025-03-16 22:00:00');

SET IDENTITY_INSERT comp.player_rating OFF;
GO

-- =============================================================================
-- comp.team_standing  (standings for active leagues)
-- =============================================================================

SET IDENTITY_INSERT comp.team_standing ON;

INSERT INTO comp.team_standing
    (standing_id, league_id, team_id, wins, losses, draws, points, maps_won, maps_lost, updated_at)
VALUES
    -- League 1 (TWR EMEA) — after both splits
    (1,  1, 1,  8,  2, 0, 24, 20, 8,  '2025-06-30 23:59:00'),
    (2,  1, 5,  7,  3, 0, 21, 18, 11, '2025-06-30 23:59:00'),
    (3,  1, 6,  5,  5, 0, 15, 13, 14, '2025-06-30 23:59:00'),
    (4,  1, 3,  4,  6, 0, 12, 10, 16, '2025-06-30 23:59:00'),
    (5,  1, 17, 3,  7, 0,  9,  8, 18, '2025-06-30 23:59:00'),
    (6,  1, 20, 1,  9, 0,  3,  4, 22, '2025-06-30 23:59:00'),

    -- League 2 (TWR NA)
    (7,  2, 2,  9,  1, 0, 27, 22, 6,  '2025-04-05 23:59:00'),
    (8,  2, 16, 7,  3, 0, 21, 18, 10, '2025-04-05 23:59:00'),
    (9,  2, 8,  4,  6, 0, 12, 11, 16, '2025-04-05 23:59:00'),
    (10, 2, 13, 2,  8, 0,  6,  7, 20, '2025-04-05 23:59:00'),

    -- League 8 (VCT EMEA) — after Stage 1 and Stage 2
    (11, 8, 11, 10, 2, 0, 30, 24, 9,  '2025-06-08 23:59:00'),
    (12, 8, 17, 8,  4, 0, 24, 20, 12, '2025-06-08 23:59:00'),
    (13, 8, 14, 5,  7, 0, 15, 14, 18, '2025-06-08 23:59:00'),
    (14, 8, 13, 3,  9, 0,  9,  9, 22, '2025-06-08 23:59:00');

SET IDENTITY_INSERT comp.team_standing OFF;
GO

PRINT '04_seed_matches_stats.sql: match (31), match_map (18), player_stat (33), player_rating (15), team_standing (14) seeded.';
GO
