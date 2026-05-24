-- =============================================================================
-- FILE:    09_broadcast.sql
-- PURPOSE: Broadcasters, broadcast rights deals, and viewership logging
-- DEPENDS: 04_tournaments_matches.sql
-- NOTE:    viewership_log placed on FG_LOGS — high volume, append-only
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.broadcaster
-- A media entity that holds rights to stream or broadcast tournaments.
-- e.g. Twitch, YouTube, ESPN Esports, regional TV networks.
-- =============================================================================

CREATE TABLE ops.broadcaster (
    broadcaster_id   INT             NOT NULL IDENTITY(1,1),
    name             NVARCHAR(150)   NOT NULL,
    platform         NVARCHAR(50)    NOT NULL,       -- Twitch, YouTube, TV, Regional OTT etc.
    region           NVARCHAR(100)   NULL,
    contact_email    NVARCHAR(254)   NULL,
    website_url      NVARCHAR(500)   NULL,
    is_active        BIT             NOT NULL DEFAULT 1,
    created_at       DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_broadcaster PRIMARY KEY CLUSTERED (broadcaster_id),
    CONSTRAINT UQ_broadcaster_name UNIQUE (name)
);
GO

-- =============================================================================
-- ops.broadcast_rights
-- The legal agreement granting a broadcaster rights to a tournament.
-- rights_type: Exclusive = only broadcaster; Non-Exclusive = shared.
-- =============================================================================

CREATE TABLE ops.broadcast_rights (
    rights_id        INT              NOT NULL IDENTITY(1,1),
    broadcaster_id   INT              NOT NULL,
    tournament_id    INT              NOT NULL,
    rights_type      NVARCHAR(20)     NOT NULL DEFAULT 'Non-Exclusive',
    territory        NVARCHAR(100)    NOT NULL,    -- 'Global', 'EMEA', 'South Africa' etc.
    fee              DECIMAL(14,2)    NULL,
    currency         NVARCHAR(5)      NOT NULL DEFAULT 'USD',
    start_date       DATE             NOT NULL,
    end_date         DATE             NOT NULL,
    status           NVARCHAR(20)     NOT NULL DEFAULT 'Active',
    created_at       DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_broadcast_rights PRIMARY KEY CLUSTERED (rights_id),
    CONSTRAINT FK_rights_broadcaster FOREIGN KEY (broadcaster_id) REFERENCES ops.broadcaster(broadcaster_id),
    CONSTRAINT FK_rights_tournament  FOREIGN KEY (tournament_id)  REFERENCES comp.tournament(tournament_id),
    CONSTRAINT CHK_rights_dates      CHECK (end_date >= start_date),
    CONSTRAINT CHK_rights_type       CHECK (rights_type IN ('Exclusive','Non-Exclusive')),
    CONSTRAINT CHK_rights_status     CHECK (status IN ('Active','Expired','Terminated'))
);
GO

-- =============================================================================
-- ops.viewership_log
-- Timestamped viewer metrics per match per broadcast rights deal.
-- Very high volume (one row per match per broadcaster) — lives on FG_LOGS.
-- Partitioned by year in 08_partitioning/03_viewership_log_partitioned.sql
-- =============================================================================

CREATE TABLE ops.viewership_log (
    log_id               BIGINT          NOT NULL IDENTITY(1,1),
    rights_id            INT             NOT NULL,
    match_id             INT             NOT NULL,
    peak_viewers         BIGINT          NOT NULL DEFAULT 0,
    avg_viewers          BIGINT          NOT NULL DEFAULT 0,
    stream_duration_min  SMALLINT        NULL,
    chat_messages        BIGINT          NULL,    -- engagement metric
    logged_at            DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_viewership_log PRIMARY KEY CLUSTERED (log_id, logged_at)
        ON FG_LOGS,
    CONSTRAINT FK_vlog_rights FOREIGN KEY (rights_id) REFERENCES ops.broadcast_rights(rights_id),
    CONSTRAINT FK_vlog_match  FOREIGN KEY (match_id)  REFERENCES comp.match(match_id),
    CONSTRAINT CHK_vlog_viewers CHECK (peak_viewers >= 0 AND avg_viewers >= 0),
    CONSTRAINT CHK_vlog_peak    CHECK (peak_viewers >= avg_viewers)
);
GO

PRINT 'ops schema: broadcaster, broadcast_rights, viewership_log created (viewership_log on FG_LOGS).';
GO