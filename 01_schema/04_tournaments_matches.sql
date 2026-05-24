-- =============================================================================
-- FILE:    04_tournaments_matches.sql
-- PURPOSE: Tournament structure, team registration, matches and map results
-- DEPENDS: 02_core_competition.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.tournament
-- A competitive event within a league (group stage, playoffs, grand final etc.)
-- =============================================================================

CREATE TABLE comp.tournament (
    tournament_id   INT              NOT NULL IDENTITY(1,1),
    league_id       INT              NOT NULL,
    name            NVARCHAR(150)    NOT NULL,
    format          NVARCHAR(30)     NOT NULL,      -- Round-Robin, Single-Elim, Double-Elim, Swiss
    prize_pool      DECIMAL(14,2)    NULL,
    currency        NVARCHAR(5)      NOT NULL DEFAULT 'USD',
    start_date      DATE             NOT NULL,
    end_date        DATE             NOT NULL,
    is_lan          BIT              NOT NULL DEFAULT 0,  -- LAN vs online
    status          NVARCHAR(20)     NOT NULL DEFAULT 'Scheduled',
    created_at      DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_tournament PRIMARY KEY CLUSTERED (tournament_id),
    CONSTRAINT FK_tournament_league FOREIGN KEY (league_id) REFERENCES comp.league(league_id),
    CONSTRAINT CHK_tournament_dates  CHECK (end_date >= start_date),
    CONSTRAINT CHK_tournament_format CHECK (format IN (
        'Round-Robin','Single-Elim','Double-Elim','Swiss','GSL','Custom')),
    CONSTRAINT CHK_tournament_status CHECK (status IN (
        'Scheduled','Ongoing','Completed','Cancelled'))
);
GO

-- =============================================================================
-- comp.tournament_team
-- Junction table: which teams are registered in which tournaments.
-- Stores seed and final placement after completion.
-- =============================================================================

CREATE TABLE comp.tournament_team (
    tournament_id    INT    NOT NULL,
    team_id          INT    NOT NULL,
    seed             INT    NULL,           -- seeding at start (1 = top seed)
    final_placement  INT    NULL,           -- placement at end (1 = winner)
    is_eliminated    BIT    NOT NULL DEFAULT 0,
    registered_at    DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_tournament_team PRIMARY KEY CLUSTERED (tournament_id, team_id),
    CONSTRAINT FK_tt_tournament FOREIGN KEY (tournament_id) REFERENCES comp.tournament(tournament_id),
    CONSTRAINT FK_tt_team       FOREIGN KEY (team_id)       REFERENCES comp.team(team_id),
    CONSTRAINT CHK_tt_seed      CHECK (seed IS NULL OR seed > 0),
    CONSTRAINT CHK_tt_placement CHECK (final_placement IS NULL OR final_placement > 0)
);
GO

-- =============================================================================
-- comp.match
-- A single head-to-head series between two teams.
-- winner_id NULL = match not yet played (scheduled).
-- =============================================================================

CREATE TABLE comp.match (
    match_id        INT              NOT NULL IDENTITY(1,1),
    tournament_id   INT              NOT NULL,
    team_a_id       INT              NOT NULL,
    team_b_id       INT              NOT NULL,
    winner_id       INT              NULL,
    score_a         TINYINT          NOT NULL DEFAULT 0,
    score_b         TINYINT          NOT NULL DEFAULT 0,
    stage           NVARCHAR(50)     NOT NULL,      -- Group Stage, Quarter-Final, etc.
    best_of         TINYINT          NOT NULL DEFAULT 1,
    status          NVARCHAR(20)     NOT NULL DEFAULT 'Scheduled',
    played_at       DATETIME2(0)     NULL,
    created_at      DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_match PRIMARY KEY CLUSTERED (match_id),
    CONSTRAINT FK_match_tournament FOREIGN KEY (tournament_id) REFERENCES comp.tournament(tournament_id),
    CONSTRAINT FK_match_team_a     FOREIGN KEY (team_a_id)     REFERENCES comp.team(team_id),
    CONSTRAINT FK_match_team_b     FOREIGN KEY (team_b_id)     REFERENCES comp.team(team_id),
    CONSTRAINT FK_match_winner     FOREIGN KEY (winner_id)     REFERENCES comp.team(team_id),
    CONSTRAINT CHK_match_teams     CHECK (team_a_id <> team_b_id),
    CONSTRAINT CHK_match_winner    CHECK (winner_id IS NULL OR
                                         winner_id = team_a_id OR
                                         winner_id = team_b_id),
    CONSTRAINT CHK_match_best_of   CHECK (best_of IN (1,3,5,7)),
    CONSTRAINT CHK_match_status    CHECK (status IN ('Scheduled','Live','Completed','Forfeited','Cancelled'))
);
GO

-- =============================================================================
-- comp.match_map
-- Individual map/game results within a match series.
-- e.g. in a Bo5, up to 5 match_map rows per match.
-- =============================================================================

CREATE TABLE comp.match_map (
    map_id          INT             NOT NULL IDENTITY(1,1),
    match_id        INT             NOT NULL,
    map_number      TINYINT         NOT NULL,       -- 1 through best_of
    map_name        NVARCHAR(100)   NULL,
    team_a_score    SMALLINT        NOT NULL DEFAULT 0,
    team_b_score    SMALLINT        NOT NULL DEFAULT 0,
    duration_min    SMALLINT        NULL,            -- map duration in minutes
    played_at       DATETIME2(0)    NULL,

    CONSTRAINT PK_match_map PRIMARY KEY CLUSTERED (map_id),
    CONSTRAINT FK_map_match FOREIGN KEY (match_id) REFERENCES comp.match(match_id),
    CONSTRAINT UQ_map_number UNIQUE (match_id, map_number),
    CONSTRAINT CHK_map_number CHECK (map_number BETWEEN 1 AND 7)
);
GO

PRINT 'comp schema: tournament, tournament_team, match, match_map created.';
GO