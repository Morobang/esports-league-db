-- =============================================================================
-- FILE:    05_stats_ratings.sql
-- PURPOSE: Player performance stats, ELO ratings, and team standings
-- DEPENDS: 04_tournaments_matches.sql
-- NOTE:    player_stat and player_rating placed on FG_STATS filegroup
--          for I/O separation from core competition tables
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.player_stat
-- Per-player performance figures for each match played.
-- High read/write volume → placed on FG_STATS.
-- =============================================================================

CREATE TABLE comp.player_stat (
    stat_id          INT             NOT NULL IDENTITY(1,1),
    match_id         INT             NOT NULL,
    player_id        INT             NOT NULL,
    kills            SMALLINT        NOT NULL DEFAULT 0,
    deaths           SMALLINT        NOT NULL DEFAULT 0,
    assists          SMALLINT        NOT NULL DEFAULT 0,
    kda_ratio        AS (CAST(
                        CASE WHEN deaths = 0
                             THEN kills + assists
                             ELSE CAST((kills + assists) AS FLOAT) / deaths
                        END AS DECIMAL(8,2))),       -- computed, not persisted
    damage_dealt     INT             NOT NULL DEFAULT 0,
    healing_done     INT             NOT NULL DEFAULT 0,
    first_blood      BIT             NOT NULL DEFAULT 0,
    mvp_flag         BIT             NOT NULL DEFAULT 0,
    created_at       DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_player_stat PRIMARY KEY CLUSTERED (stat_id)
        ON FG_STATS,
    CONSTRAINT FK_stat_match  FOREIGN KEY (match_id)  REFERENCES comp.match(match_id),
    CONSTRAINT FK_stat_player FOREIGN KEY (player_id) REFERENCES comp.player(player_id),
    CONSTRAINT UQ_stat_match_player UNIQUE (match_id, player_id),
    CONSTRAINT CHK_stat_kills   CHECK (kills   >= 0),
    CONSTRAINT CHK_stat_deaths  CHECK (deaths  >= 0),
    CONSTRAINT CHK_stat_assists CHECK (assists >= 0)
);
GO

-- =============================================================================
-- comp.player_rating
-- Snapshot ELO/rating score per player per tournament.
-- Recalculated after each match by the usp_calculate_standings procedure.
-- =============================================================================

CREATE TABLE comp.player_rating (
    rating_id        INT             NOT NULL IDENTITY(1,1),
    player_id        INT             NOT NULL,
    tournament_id    INT             NOT NULL,
    elo_score        DECIMAL(8,2)    NOT NULL DEFAULT 1000.00,
    rank_position    INT             NULL,
    games_played     INT             NOT NULL DEFAULT 0,
    win_rate         DECIMAL(5,2)    NULL,
    calculated_at    DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_player_rating PRIMARY KEY CLUSTERED (rating_id)
        ON FG_STATS,
    CONSTRAINT FK_rating_player     FOREIGN KEY (player_id)     REFERENCES comp.player(player_id),
    CONSTRAINT FK_rating_tournament FOREIGN KEY (tournament_id) REFERENCES comp.tournament(tournament_id),
    CONSTRAINT UQ_rating_player_tournament UNIQUE (player_id, tournament_id),
    CONSTRAINT CHK_rating_elo       CHECK (elo_score >= 0),
    CONSTRAINT CHK_rating_winrate   CHECK (win_rate IS NULL OR win_rate BETWEEN 0 AND 100)
);
GO

-- =============================================================================
-- comp.team_standing
-- Aggregated win/loss record per team per league.
-- Updated by usp_calculate_standings after each match result.
-- =============================================================================

CREATE TABLE comp.team_standing (
    standing_id      INT             NOT NULL IDENTITY(1,1),
    league_id        INT             NOT NULL,
    team_id          INT             NOT NULL,
    wins             SMALLINT        NOT NULL DEFAULT 0,
    losses           SMALLINT        NOT NULL DEFAULT 0,
    draws            SMALLINT        NOT NULL DEFAULT 0,
    points           SMALLINT        NOT NULL DEFAULT 0,
    maps_won         SMALLINT        NOT NULL DEFAULT 0,
    maps_lost        SMALLINT        NOT NULL DEFAULT 0,
    map_diff         AS (maps_won - maps_lost),    -- computed column
    updated_at       DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_team_standing PRIMARY KEY CLUSTERED (standing_id),
    CONSTRAINT FK_standing_league FOREIGN KEY (league_id) REFERENCES comp.league(league_id),
    CONSTRAINT FK_standing_team   FOREIGN KEY (team_id)   REFERENCES comp.team(team_id),
    CONSTRAINT UQ_standing_league_team UNIQUE (league_id, team_id),
    CONSTRAINT CHK_standing_wins   CHECK (wins   >= 0),
    CONSTRAINT CHK_standing_losses CHECK (losses >= 0),
    CONSTRAINT CHK_standing_points CHECK (points >= 0)
);
GO

PRINT 'comp schema: player_stat, player_rating, team_standing created (player_stat & rating on FG_STATS).';
GO