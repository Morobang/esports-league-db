-- =============================================================================
-- FILE:    02_usp_record_match_result.sql
-- PURPOSE: Record a completed match result, update team standings,
--          and flag eliminated teams in knockout tournaments
-- DEPENDS: 01_usp_register_team.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.usp_record_match_result
--
-- Records the outcome of a match. In a single transaction:
--   1. Validates match exists and is Scheduled or Live
--   2. Validates winner is one of the two competing teams
--   3. Updates comp.match (winner, scores, status, played_at)
--   4. Upserts comp.team_standing for both teams in the match's league
--   5. In Single-Elim / Double-Elim formats, marks the loser as eliminated
--   6. Writes audit log entries for all changes
--
-- Parameters:
--   @match_id       INT           - match to resolve
--   @winner_id      INT           - team_id of the winner
--   @score_a        TINYINT       - series score for team_a (e.g. 3 in a 3-1)
--   @score_b        TINYINT       - series score for team_b
--   @played_at      DATETIME2     - when the match concluded (defaults to now)
--   @result_msg     NVARCHAR OUT  - outcome message
--   @success        BIT OUT       - 1 = recorded, 0 = failed
-- =============================================================================

CREATE OR ALTER PROCEDURE comp.usp_record_match_result
    @match_id    INT,
    @winner_id   INT,
    @score_a     TINYINT,
    @score_b     TINYINT,
    @played_at   DATETIME2(0)  = NULL,
    @result_msg  NVARCHAR(400) = NULL OUTPUT,
    @success     BIT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Defaults
    SET @success   = 0;
    SET @result_msg = '';
    IF @played_at IS NULL SET @played_at = SYSUTCDATETIME();

    DECLARE
        @team_a_id       INT,
        @team_b_id       INT,
        @loser_id        INT,
        @tournament_id   INT,
        @league_id       INT,
        @match_status    NVARCHAR(20),
        @tournament_fmt  NVARCHAR(30),
        @team_a_name     NVARCHAR(100),
        @team_b_name     NVARCHAR(100),
        @winner_name     NVARCHAR(100),
        @maps_a          TINYINT,
        @maps_b          TINYINT;

    -- -------------------------------------------------------------------------
    -- 1. Load match details
    -- -------------------------------------------------------------------------
    SELECT
        @team_a_id     = m.team_a_id,
        @team_b_id     = m.team_b_id,
        @tournament_id = m.tournament_id,
        @match_status  = m.status,
        @tournament_fmt= tn.format,
        @league_id     = tn.league_id
    FROM comp.match m
    JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
    WHERE m.match_id = @match_id;

    IF @team_a_id IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: Match ID ', @match_id, ' does not exist.');
        RETURN;
    END

    IF @match_status NOT IN ('Scheduled', 'Live')
    BEGIN
        SET @result_msg = CONCAT('ERROR: Match ', @match_id,
                                 ' is already ', @match_status, ' — cannot re-record.');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 2. Validate winner is a participant
    -- -------------------------------------------------------------------------
    IF @winner_id NOT IN (@team_a_id, @team_b_id)
    BEGIN
        SET @result_msg = CONCAT('ERROR: Winner ID ', @winner_id,
                                 ' is not a participant in match ', @match_id, '.');
        RETURN;
    END

    -- Derive loser and map scores
    SET @loser_id = CASE WHEN @winner_id = @team_a_id THEN @team_b_id ELSE @team_a_id END;
    SET @maps_a   = CASE WHEN @winner_id = @team_a_id THEN @score_a ELSE @score_b END;
    SET @maps_b   = CASE WHEN @winner_id = @team_b_id THEN @score_a ELSE @score_b END;

    -- Team names for messaging
    SELECT @team_a_name = name FROM comp.team WHERE team_id = @team_a_id;
    SELECT @team_b_name = name FROM comp.team WHERE team_id = @team_b_id;
    SELECT @winner_name = name FROM comp.team WHERE team_id = @winner_id;

    -- -------------------------------------------------------------------------
    -- 3. Record everything in a single transaction
    -- -------------------------------------------------------------------------
    BEGIN TRANSACTION;
    BEGIN TRY

        -- 3a. Update the match record
        UPDATE comp.match
        SET
            winner_id = @winner_id,
            score_a   = @score_a,
            score_b   = @score_b,
            status    = 'Completed',
            played_at = @played_at
        WHERE match_id = @match_id;

        -- 3b. Upsert team_standing for WINNER
        IF EXISTS (
            SELECT 1 FROM comp.team_standing
            WHERE league_id = @league_id AND team_id = @winner_id
        )
        BEGIN
            UPDATE comp.team_standing
            SET
                wins       = wins + 1,
                points     = points + 3,
                maps_won   = maps_won  + @maps_a,
                maps_lost  = maps_lost + @maps_b,
                updated_at = SYSUTCDATETIME()
            WHERE league_id = @league_id AND team_id = @winner_id;
        END
        ELSE
        BEGIN
            INSERT INTO comp.team_standing
                (league_id, team_id, wins, losses, draws, points, maps_won, maps_lost, updated_at)
            VALUES
                (@league_id, @winner_id, 1, 0, 0, 3, @maps_a, @maps_b, SYSUTCDATETIME());
        END

        -- 3c. Upsert team_standing for LOSER
        IF EXISTS (
            SELECT 1 FROM comp.team_standing
            WHERE league_id = @league_id AND team_id = @loser_id
        )
        BEGIN
            UPDATE comp.team_standing
            SET
                losses     = losses + 1,
                maps_won   = maps_won  + @maps_b,
                maps_lost  = maps_lost + @maps_a,
                updated_at = SYSUTCDATETIME()
            WHERE league_id = @league_id AND team_id = @loser_id;
        END
        ELSE
        BEGIN
            INSERT INTO comp.team_standing
                (league_id, team_id, wins, losses, draws, points, maps_won, maps_lost, updated_at)
            VALUES
                (@league_id, @loser_id, 0, 1, 0, 0, @maps_b, @maps_a, SYSUTCDATETIME());
        END

        -- 3d. Mark loser as eliminated in knockout formats
        IF @tournament_fmt IN ('Single-Elim', 'Double-Elim')
        BEGIN
            UPDATE comp.tournament_team
            SET is_eliminated = 1
            WHERE tournament_id = @tournament_id
              AND team_id = @loser_id;
        END

        -- 3e. Audit log
        INSERT INTO audit.log
            (schema_name, table_name, operation, record_id, new_value, changed_by, app_context)
        VALUES
            ('comp', 'match', 'UPDATE', @match_id,
             CONCAT('winner_id=', @winner_id, ' | score=', @score_a, '-', @score_b,
                    ' | status=Completed | played_at=', CONVERT(NVARCHAR, @played_at, 120)),
             SYSTEM_USER, 'usp_record_match_result');

        COMMIT TRANSACTION;

        SET @success = 1;
        SET @result_msg = CONCAT(
            'SUCCESS: Match ', @match_id, ' recorded — ',
            @winner_name, ' defeated ',
            CASE WHEN @winner_id = @team_a_id THEN @team_b_name ELSE @team_a_name END,
            ' (', @score_a, '–', @score_b, ').',
            CASE WHEN @tournament_fmt IN ('Single-Elim','Double-Elim')
                 THEN CONCAT(' ', CASE WHEN @winner_id = @team_a_id THEN @team_b_name ELSE @team_a_name END, ' eliminated.')
                 ELSE ''
            END
        );

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @result_msg = CONCAT('ERROR: ', ERROR_MESSAGE());
    END CATCH
END;
GO

-- =============================================================================
-- Usage example:
-- DECLARE @msg NVARCHAR(400), @ok BIT;
-- EXEC comp.usp_record_match_result
--     @match_id   = 1,
--     @winner_id  = 1,
--     @score_a    = 2,
--     @score_b    = 0,
--     @result_msg = @msg OUTPUT,
--     @success    = @ok  OUTPUT;
-- SELECT @ok AS success, @msg AS message;
-- =============================================================================

PRINT '02_usp_record_match_result: procedure created.';
GO
