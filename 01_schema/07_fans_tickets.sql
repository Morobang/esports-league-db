-- =============================================================================
-- FILE:    07_fans_tickets.sql
-- PURPOSE: Fan accounts and ticket purchase orders
-- DEPENDS: 06_venues_events.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.fan
-- Registered fan accounts. Tracks favourite team and registration date.
-- =============================================================================

CREATE TABLE ops.fan (
    fan_id              INT             NOT NULL IDENTITY(1,1),
    username            NVARCHAR(60)    NOT NULL,
    email               NVARCHAR(254)   NOT NULL,
    country             NVARCHAR(100)   NULL,
    favourite_team_id   INT             NULL,
    registered_at       DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    last_login          DATETIME2(0)    NULL,
    is_active           BIT             NOT NULL DEFAULT 1,

    CONSTRAINT PK_fan PRIMARY KEY CLUSTERED (fan_id),
    CONSTRAINT UQ_fan_username UNIQUE (username),
    CONSTRAINT UQ_fan_email    UNIQUE (email),
    CONSTRAINT FK_fan_team     FOREIGN KEY (favourite_team_id) REFERENCES comp.team(team_id)
);
GO

-- =============================================================================
-- ops.ticket_order
-- A fan's purchase of one or more seats in a ticket tier.
-- Total amount is stored at order time (price may change later).
-- =============================================================================

CREATE TABLE ops.ticket_order (
    order_id       INT              NOT NULL IDENTITY(1,1),
    fan_id         INT              NOT NULL,
    tier_id        INT              NOT NULL,
    quantity       TINYINT          NOT NULL DEFAULT 1,
    unit_price     DECIMAL(10,2)    NOT NULL,
    total_amount   DECIMAL(12,2)    NOT NULL,
    currency       NVARCHAR(5)      NOT NULL DEFAULT 'USD',
    status         NVARCHAR(20)     NOT NULL DEFAULT 'Confirmed',
    payment_ref    NVARCHAR(100)    NULL,
    ordered_at     DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at     DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_ticket_order PRIMARY KEY CLUSTERED (order_id),
    CONSTRAINT FK_order_fan  FOREIGN KEY (fan_id)   REFERENCES ops.fan(fan_id),
    CONSTRAINT FK_order_tier FOREIGN KEY (tier_id)  REFERENCES ops.ticket_tier(tier_id),
    CONSTRAINT CHK_order_qty    CHECK (quantity >= 1),
    CONSTRAINT CHK_order_amount CHECK (total_amount >= 0),
    CONSTRAINT CHK_order_status CHECK (status IN ('Pending','Confirmed','Cancelled','Refunded'))
);
GO

PRINT 'ops schema: fan, ticket_order created.';
GO