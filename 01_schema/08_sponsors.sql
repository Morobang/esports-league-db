-- =============================================================================
-- FILE:    08_sponsors.sql
-- PURPOSE: Sponsor companies and their deal relationships with teams/tournaments
-- DEPENDS: 02_core_competition.sql, 04_tournaments_matches.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.sponsor
-- A company that financially backs teams or tournaments.
-- =============================================================================

CREATE TABLE ops.sponsor (
    sponsor_id      INT             NOT NULL IDENTITY(1,1),
    company_name    NVARCHAR(150)   NOT NULL,
    industry        NVARCHAR(100)   NULL,         -- Gaming, Tech, Energy Drink, Apparel etc.
    website_url     NVARCHAR(500)   NULL,
    contact_email   NVARCHAR(254)   NULL,
    tier            NVARCHAR(20)    NOT NULL DEFAULT 'Silver',  -- Title, Gold, Silver, Bronze
    is_active       BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_sponsor PRIMARY KEY CLUSTERED (sponsor_id),
    CONSTRAINT UQ_sponsor_name UNIQUE (company_name),
    CONSTRAINT CHK_sponsor_tier CHECK (tier IN ('Title','Gold','Silver','Bronze','Partner'))
);
GO

-- =============================================================================
-- ops.sponsorship
-- A specific deal between a sponsor and either a team or a tournament.
-- team_id and tournament_id are both nullable — at least one must be set.
-- visibility_type describes where the brand appears.
-- =============================================================================

CREATE TABLE ops.sponsorship (
    sponsorship_id    INT              NOT NULL IDENTITY(1,1),
    sponsor_id        INT              NOT NULL,
    team_id           INT              NULL,
    tournament_id     INT              NULL,
    deal_value        DECIMAL(14,2)    NOT NULL,
    currency          NVARCHAR(5)      NOT NULL DEFAULT 'USD',
    start_date        DATE             NOT NULL,
    end_date          DATE             NOT NULL,
    visibility_type   NVARCHAR(50)     NOT NULL,    -- Jersey, Banner, Title, Broadcast, Digital
    status            NVARCHAR(20)     NOT NULL DEFAULT 'Active',
    created_at        DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_sponsorship PRIMARY KEY CLUSTERED (sponsorship_id),
    CONSTRAINT FK_sponsorship_sponsor    FOREIGN KEY (sponsor_id)    REFERENCES ops.sponsor(sponsor_id),
    CONSTRAINT FK_sponsorship_team       FOREIGN KEY (team_id)       REFERENCES comp.team(team_id),
    CONSTRAINT FK_sponsorship_tournament FOREIGN KEY (tournament_id) REFERENCES comp.tournament(tournament_id),
    CONSTRAINT CHK_sponsorship_target    CHECK (team_id IS NOT NULL OR tournament_id IS NOT NULL),
    CONSTRAINT CHK_sponsorship_dates     CHECK (end_date > start_date),
    CONSTRAINT CHK_sponsorship_value     CHECK (deal_value >= 0),
    CONSTRAINT CHK_sponsorship_status    CHECK (status IN ('Active','Expired','Terminated')),
    CONSTRAINT CHK_sponsorship_visibility CHECK (visibility_type IN (
        'Jersey','Banner','Title','Broadcast','Digital','Naming Rights','Other'))
);
GO

PRINT 'ops schema: sponsor, sponsorship created.';
GO