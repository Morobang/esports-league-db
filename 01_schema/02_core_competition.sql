-- =============================================================================
-- FILE:    02_core_competition.sql
-- PURPOSE: Core competition tables — game, region, league, team, player, staff
-- DEPENDS: 01_create_database.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.game
-- Root entity. Every league is scoped to one game.
-- =============================================================================

CREATE TABLE comp.game (
    game_id     INT             NOT NULL IDENTITY(1,1),
    name        NVARCHAR(100)   NOT NULL,
    genre       NVARCHAR(50)    NOT NULL,
    publisher   NVARCHAR(100)   NOT NULL,
    platform    NVARCHAR(50)    NOT NULL,          -- PC, Console, Mobile, Cross-platform
    is_active   BIT             NOT NULL DEFAULT 1,
    created_at  DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_game PRIMARY KEY CLUSTERED (game_id),
    CONSTRAINT UQ_game_name UNIQUE (name),
    CONSTRAINT CHK_game_platform CHECK (platform IN (
        'PC', 'Console', 'Mobile', 'Cross-platform'))
);
GO

-- =============================================================================
-- comp.region
-- Geographic scoping for leagues and teams.
-- =============================================================================

CREATE TABLE comp.region (
    region_id   INT             NOT NULL IDENTITY(1,1),
    name        NVARCHAR(100)   NOT NULL,
    code        NVARCHAR(10)    NOT NULL,          -- e.g. EMEA, NA, SEA
    timezone    NVARCHAR(60)    NOT NULL,          -- IANA timezone string

    CONSTRAINT PK_region PRIMARY KEY CLUSTERED (region_id),
    CONSTRAINT UQ_region_code UNIQUE (code)
);
GO

-- =============================================================================
-- comp.league
-- A league ties a game to a region and season (e.g. "KOF XV EMEA Season 2").
-- =============================================================================

CREATE TABLE comp.league (
    league_id   INT             NOT NULL IDENTITY(1,1),
    game_id     INT             NOT NULL,
    region_id   INT             NOT NULL,
    name        NVARCHAR(150)   NOT NULL,
    tier        NVARCHAR(20)    NOT NULL DEFAULT 'Tier1', -- Tier1, Tier2, Tier3, Open
    season      NVARCHAR(20)    NOT NULL,
    start_date  DATE            NOT NULL,
    end_date    DATE            NOT NULL,
    is_active   BIT             NOT NULL DEFAULT 1,
    created_at  DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_league PRIMARY KEY CLUSTERED (league_id),
    CONSTRAINT FK_league_game   FOREIGN KEY (game_id)   REFERENCES comp.game(game_id),
    CONSTRAINT FK_league_region FOREIGN KEY (region_id) REFERENCES comp.region(region_id),
    CONSTRAINT CHK_league_dates CHECK (end_date > start_date),
    CONSTRAINT CHK_league_tier  CHECK (tier IN ('Tier1','Tier2','Tier3','Open'))
);
GO

-- =============================================================================
-- comp.team
-- A participating organisation. Can enter multiple leagues and tournaments.
-- =============================================================================

CREATE TABLE comp.team (
    team_id     INT             NOT NULL IDENTITY(1,1),
    region_id   INT             NOT NULL,
    name        NVARCHAR(100)   NOT NULL,
    tag         NVARCHAR(10)    NOT NULL,          -- short tag e.g. "TL", "FNC"
    logo_url    NVARCHAR(500)   NULL,
    founded_at  DATE            NULL,
    is_active   BIT             NOT NULL DEFAULT 1,
    created_at  DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_team PRIMARY KEY CLUSTERED (team_id),
    CONSTRAINT UQ_team_name UNIQUE (name),
    CONSTRAINT UQ_team_tag  UNIQUE (tag),
    CONSTRAINT FK_team_region FOREIGN KEY (region_id) REFERENCES comp.region(region_id)
);
GO

-- =============================================================================
-- comp.player
-- An individual competitor. Tracks current team and role.
-- left_at NULL means still on the roster.
-- =============================================================================

CREATE TABLE comp.player (
    player_id   INT             NOT NULL IDENTITY(1,1),
    team_id     INT             NULL,              -- NULL = free agent
    username    NVARCHAR(60)    NOT NULL,
    real_name   NVARCHAR(150)   NULL,
    nationality NVARCHAR(60)    NULL,
    role        NVARCHAR(50)    NULL,              -- e.g. IGL, Support, Carry
    status      NVARCHAR(20)    NOT NULL DEFAULT 'Active',
    joined_at   DATE            NULL,
    left_at     DATE            NULL,
    created_at  DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_player PRIMARY KEY CLUSTERED (player_id),
    CONSTRAINT UQ_player_username UNIQUE (username),
    CONSTRAINT FK_player_team FOREIGN KEY (team_id) REFERENCES comp.team(team_id),
    CONSTRAINT CHK_player_status CHECK (status IN ('Active','Inactive','Retired','Banned')),
    CONSTRAINT CHK_player_dates  CHECK (left_at IS NULL OR left_at >= joined_at)
);
GO

-- =============================================================================
-- comp.staff
-- Non-playing team personnel: coaches, analysts, managers.
-- =============================================================================

CREATE TABLE comp.staff (
    staff_id    INT             NOT NULL IDENTITY(1,1),
    team_id     INT             NOT NULL,
    full_name   NVARCHAR(150)   NOT NULL,
    role        NVARCHAR(50)    NOT NULL,          -- Head Coach, Analyst, Manager etc.
    nationality NVARCHAR(60)    NULL,
    joined_at   DATE            NULL,
    left_at     DATE            NULL,
    created_at  DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_staff PRIMARY KEY CLUSTERED (staff_id),
    CONSTRAINT FK_staff_team FOREIGN KEY (team_id) REFERENCES comp.team(team_id),
    CONSTRAINT CHK_staff_dates CHECK (left_at IS NULL OR left_at >= joined_at)
);
GO

PRINT 'comp schema: game, region, league, team, player, staff created.';
GO