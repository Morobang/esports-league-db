-- =============================================================================
-- FILE:    10_audit.sql
-- PURPOSE: Centralised audit log for all DDL/DML change tracking
-- DEPENDS: 01_create_database.sql
-- NOTE:    Placed on FG_LOGS. Partitioned by month in 08_partitioning/.
--          Do NOT add foreign keys here — audit.log must survive table drops.
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- audit.log
-- Append-only change log. Populated by triggers or application layer.
-- old_value / new_value stored as NVARCHAR(MAX) for flexibility.
-- Partition key: changed_at (DATETIME2) — partitioned by month.
-- =============================================================================

CREATE TABLE audit.log (
    log_id        BIGINT          NOT NULL IDENTITY(1,1),
    schema_name   NVARCHAR(50)    NOT NULL,
    table_name    NVARCHAR(100)   NOT NULL,
    operation     NVARCHAR(10)    NOT NULL,          -- INSERT, UPDATE, DELETE
    record_id     INT             NULL,              -- PK of the affected row
    column_name   NVARCHAR(100)   NULL,              -- NULL = full row log
    old_value     NVARCHAR(MAX)   NULL,
    new_value     NVARCHAR(MAX)   NULL,
    changed_by    NVARCHAR(150)   NOT NULL DEFAULT SYSTEM_USER,
    app_context   NVARCHAR(100)   NULL,              -- stored proc or API endpoint name
    changed_at    DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_audit_log PRIMARY KEY CLUSTERED (log_id, changed_at)
        ON FG_LOGS,
    CONSTRAINT CHK_audit_operation CHECK (operation IN ('INSERT','UPDATE','DELETE','MERGE'))
);
GO

-- =============================================================================
-- Trigger example: auto-audit on comp.contract changes
-- =============================================================================

CREATE OR ALTER TRIGGER comp.trg_contract_audit
ON comp.contract
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    INSERT INTO audit.log (schema_name, table_name, operation, record_id, new_value, changed_by)
    SELECT 'comp', 'contract', 'INSERT', i.contract_id,
           CONCAT('player_id=', i.player_id, ' | salary=', i.salary_monthly, ' | status=', i.status),
           SYSTEM_USER
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM deleted);

    -- UPDATE
    INSERT INTO audit.log (schema_name, table_name, operation, record_id, old_value, new_value, changed_by)
    SELECT 'comp', 'contract', 'UPDATE', i.contract_id,
           CONCAT('player_id=', d.player_id, ' | salary=', d.salary_monthly, ' | status=', d.status),
           CONCAT('player_id=', i.player_id, ' | salary=', i.salary_monthly, ' | status=', i.status),
           SYSTEM_USER
    FROM inserted i
    JOIN deleted d ON i.contract_id = d.contract_id;

    -- DELETE
    INSERT INTO audit.log (schema_name, table_name, operation, record_id, old_value, changed_by)
    SELECT 'comp', 'contract', 'DELETE', d.contract_id,
           CONCAT('player_id=', d.player_id, ' | salary=', d.salary_monthly, ' | status=', d.status),
           SYSTEM_USER
    FROM deleted d
    WHERE NOT EXISTS (SELECT 1 FROM inserted);
END;
GO

PRINT 'audit schema: log table and trg_contract_audit trigger created.';
GO