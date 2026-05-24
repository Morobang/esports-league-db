-- =============================================================================
-- FILE:    03_contracts.sql
-- PURPOSE: Player contracts and salary tracking
-- DEPENDS: 02_core_competition.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.contract
-- Tracks a player's financial agreement with a team.
-- A player can have multiple contracts over time (history preserved).
-- Only one contract should be Active per player at any time — enforced via
-- the filtered unique index below.
-- =============================================================================

CREATE TABLE comp.contract (
    contract_id      INT              NOT NULL IDENTITY(1,1),
    player_id        INT              NOT NULL,
    team_id          INT              NOT NULL,
    salary_monthly   DECIMAL(12,2)    NOT NULL,
    currency         NVARCHAR(5)      NOT NULL DEFAULT 'USD',
    start_date       DATE             NOT NULL,
    end_date         DATE             NOT NULL,
    status           NVARCHAR(20)     NOT NULL DEFAULT 'Active',
    buyout_clause    DECIMAL(14,2)    NULL,        -- optional release clause
    notes            NVARCHAR(500)    NULL,
    created_at       DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at       DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_contract PRIMARY KEY CLUSTERED (contract_id),
    CONSTRAINT FK_contract_player FOREIGN KEY (player_id) REFERENCES comp.player(player_id),
    CONSTRAINT FK_contract_team   FOREIGN KEY (team_id)   REFERENCES comp.team(team_id),
    CONSTRAINT CHK_contract_dates  CHECK (end_date > start_date),
    CONSTRAINT CHK_contract_salary CHECK (salary_monthly >= 0),
    CONSTRAINT CHK_contract_status CHECK (status IN ('Active','Expired','Terminated','Suspended'))
);
GO

-- Only one Active contract per player at a time
CREATE UNIQUE INDEX UQ_contract_active_player
    ON comp.contract (player_id)
    WHERE status = 'Active';
GO

PRINT 'comp schema: contract created.';
GO