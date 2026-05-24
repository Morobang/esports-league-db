-- =============================================================================
-- FILE:    06_venues_events.sql
-- PURPOSE: Physical venues, tournament events, and ticket tiers
-- DEPENDS: 04_tournaments_matches.sql, 02_core_competition.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.venue
-- A physical location where LAN events are hosted.
-- =============================================================================

CREATE TABLE ops.venue (
    venue_id     INT              NOT NULL IDENTITY(1,1),
    region_id    INT              NOT NULL,
    name         NVARCHAR(150)    NOT NULL,
    city         NVARCHAR(100)    NOT NULL,
    country      NVARCHAR(100)    NOT NULL,
    capacity     INT              NOT NULL,
    address      NVARCHAR(300)    NULL,
    is_active    BIT              NOT NULL DEFAULT 1,
    created_at   DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_venue PRIMARY KEY CLUSTERED (venue_id),
    CONSTRAINT FK_venue_region FOREIGN KEY (region_id) REFERENCES comp.region(region_id),
    CONSTRAINT CHK_venue_capacity CHECK (capacity > 0)
);
GO

-- =============================================================================
-- ops.event
-- A scheduled event day or block within a tournament.
-- One tournament may span multiple event days.
-- =============================================================================

CREATE TABLE ops.event (
    event_id              INT              NOT NULL IDENTITY(1,1),
    tournament_id         INT              NOT NULL,
    venue_id              INT              NULL,          -- NULL = online event
    name                  NVARCHAR(200)    NOT NULL,
    event_type            NVARCHAR(30)     NOT NULL,      -- GroupStage, Playoff, GrandFinal, Opening
    start_datetime        DATETIME2(0)     NOT NULL,
    end_datetime          DATETIME2(0)     NOT NULL,
    expected_attendance   INT              NULL,
    actual_attendance     INT              NULL,
    stream_url            NVARCHAR(500)    NULL,
    status                NVARCHAR(20)     NOT NULL DEFAULT 'Scheduled',
    created_at            DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_event PRIMARY KEY CLUSTERED (event_id),
    CONSTRAINT FK_event_tournament FOREIGN KEY (tournament_id) REFERENCES comp.tournament(tournament_id),
    CONSTRAINT FK_event_venue      FOREIGN KEY (venue_id)      REFERENCES ops.venue(venue_id),
    CONSTRAINT CHK_event_dates     CHECK (end_datetime > start_datetime),
    CONSTRAINT CHK_event_type      CHECK (event_type IN (
        'GroupStage','Playoff','QuarterFinal','SemiFinal','GrandFinal','Opening','Ceremony','Other')),
    CONSTRAINT CHK_event_status    CHECK (status IN ('Scheduled','Live','Completed','Postponed','Cancelled'))
);
GO

-- =============================================================================
-- ops.ticket_tier
-- Pricing tiers for a ticketed event (General, VIP, Premium etc.)
-- seats_sold is updated by usp_issue_ticket.
-- =============================================================================

CREATE TABLE ops.ticket_tier (
    tier_id       INT             NOT NULL IDENTITY(1,1),
    event_id      INT             NOT NULL,
    tier_name     NVARCHAR(50)    NOT NULL,
    price         DECIMAL(10,2)   NOT NULL,
    currency      NVARCHAR(5)     NOT NULL DEFAULT 'USD',
    total_seats   INT             NOT NULL,
    seats_sold    INT             NOT NULL DEFAULT 0,
    seats_avail   AS (total_seats - seats_sold),   -- computed
    sale_start    DATETIME2(0)    NULL,
    sale_end      DATETIME2(0)    NULL,
    created_at    DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_ticket_tier PRIMARY KEY CLUSTERED (tier_id),
    CONSTRAINT FK_tier_event  FOREIGN KEY (event_id) REFERENCES ops.event(event_id),
    CONSTRAINT UQ_tier_name   UNIQUE (event_id, tier_name),
    CONSTRAINT CHK_tier_price CHECK (price >= 0),
    CONSTRAINT CHK_tier_seats CHECK (total_seats > 0 AND seats_sold >= 0 AND seats_sold <= total_seats)
);
GO

PRINT 'ops schema: venue, event, ticket_tier created.';
GO