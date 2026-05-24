-- =============================================================================
-- FILE:    01_usp_register_team.sql
-- PURPOSE: Register a team into a tournament with validation
-- DEPENDS: 04_views/
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.usp_register_team
--
-- Registers a team into a tournament. Validates:
--   1. Tournament exists and is in Scheduled/Ongoing status
--   2. Team exists and is active
--   3. Team is not already registered
--   4. Tournament has not exceeded a max team cap (16)
--
-- Parameters:
--   @tournament_id   INT           - target tournament
--   @team_id         INT           - team to register
--   @seed            INT = NULL    - optional seeding position
--   @result_msg      NVARCHAR OUT  - human-readable outcome message
--   @success         BIT OUT       - 1 = registered, 0 = failed
-- =============================================================================

CREATE OR ALTER PROCEDURE comp.usp_register_team
    @tournament_id   INT,
    @team_id         INT,
    @seed            INT           = NULL,
    @result_msg      NVARCHAR(300) = NULL OUTPUT,
    @success         BIT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tournament_name NVARCHAR(150);
    DECLARE @tournament_status NVARCHAR(20);
    DECLARE @team_name NVARCHAR(100);
    DECLARE @team_active BIT;
    DECLARE @already_registered INT;
    DECLARE @current_team_count INT;
    DECLARE @max_teams INT = 16;

    -- Default outputs
    SET @success = 0;
    SET @result_msg = '';

    -- -------------------------------------------------------------------------
    -- 1. Validate tournament
    -- -------------------------------------------------------------------------
    SELECT
        @tournament_name   = name,
        @tournament_status = status
    FROM comp.tournament
    WHERE tournament_id = @tournament_id;

    IF @tournament_name IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: Tournament ID ', @tournament_id, ' does not exist.');
        RETURN;
    END

    IF @tournament_status NOT IN ('Scheduled', 'Ongoing')
    BEGIN
        SET @result_msg = CONCAT('ERROR: Tournament "', @tournament_name,
                                 '" is ', @tournament_status, ' — registration is closed.');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 2. Validate team
    -- -------------------------------------------------------------------------
    SELECT
        @team_name   = name,
        @team_active = is_active
    FROM comp.team
    WHERE team_id = @team_id;

    IF @team_name IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: Team ID ', @team_id, ' does not exist.');
        RETURN;
    END

    IF @team_active = 0
    BEGIN
        SET @result_msg = CONCAT('ERROR: Team "', @team_name, '" is inactive and cannot be registered.');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 3. Check for duplicate registration
    -- -------------------------------------------------------------------------
    SELECT @already_registered = COUNT(*)
    FROM comp.tournament_team
    WHERE tournament_id = @tournament_id
      AND team_id = @team_id;

    IF @already_registered > 0
    BEGIN
        SET @result_msg = CONCAT('ERROR: Team "', @team_name,
                                 '" is already registered in "', @tournament_name, '".');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 4. Check team cap
    -- -------------------------------------------------------------------------
    SELECT @current_team_count = COUNT(*)
    FROM comp.tournament_team
    WHERE tournament_id = @tournament_id;

    IF @current_team_count >= @max_teams
    BEGIN
        SET @result_msg = CONCAT('ERROR: Tournament "', @tournament_name,
                                 '" has reached the maximum of ', @max_teams, ' teams.');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 5. Register the team
    -- -------------------------------------------------------------------------
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO comp.tournament_team (tournament_id, team_id, seed, is_eliminated, registered_at)
        VALUES (@tournament_id, @team_id, @seed, 0, SYSUTCDATETIME());

        -- Log to audit
        INSERT INTO audit.log (schema_name, table_name, operation, record_id, new_value, changed_by, app_context)
        VALUES ('comp', 'tournament_team', 'INSERT', @team_id,
                CONCAT('tournament_id=', @tournament_id, ' | seed=', ISNULL(CAST(@seed AS NVARCHAR), 'NULL')),
                SYSTEM_USER, 'usp_register_team');

        COMMIT TRANSACTION;

        SET @success = 1;
        SET @result_msg = CONCAT('SUCCESS: Team "', @team_name,
                                 '" registered in "', @tournament_name, '"',
                                 CASE WHEN @seed IS NOT NULL
                                      THEN CONCAT(' with seed #', @seed)
                                      ELSE ' (unseeded)'
                                 END, '.');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @result_msg = CONCAT('ERROR: Unexpected failure — ', ERROR_MESSAGE());
    END CATCH
END;
GO

-- =============================================================================
-- Usage example:
-- DECLARE @msg NVARCHAR(300), @ok BIT;
-- EXEC comp.usp_register_team
--     @tournament_id = 16,
--     @team_id       = 1,
--     @seed          = 4,
--     @result_msg    = @msg OUTPUT,
--     @success       = @ok  OUTPUT;
-- SELECT @ok AS success, @msg AS message;
-- =============================================================================

PRINT '01_usp_register_team: procedure created.';
GO
