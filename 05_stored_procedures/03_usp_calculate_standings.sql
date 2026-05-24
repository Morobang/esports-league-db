-- =============================================================================
-- FILE:    03_usp_calculate_standings.sql
-- PURPOSE: Recalculate team standings from raw match results and
--          update player ELO ratings for a given league or tournament
-- DEPENDS: 02_usp_record_match_result.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.usp_calculate_standings
--
-- Full recalculation procedure — rebuilds standings from scratch using
-- completed match data. Safe to re-run at any time (idempotent).
--
-- For ELO: applies a simplified Elo formula per completed match.
--   Expected score  = 1 / (1 + 10^((opponent_elo - player_elo) / 400))
--   New elo         = old_elo + K * (actual - expected)
--   K factor        = 32 (standard competitive)
--
-- Parameters:
--   @league_id        INT  - recalculate standings for this league
--   @tournament_id    INT  - recalculate ELO for this tournament (can be NULL)
--   @result_msg       NVARCHAR OUT
--   @success          BIT OUT
-- =============================================================================

CREATE OR ALTER PROCEDURE comp.usp_calculate_standings
    @league_id       INT,
    @tournament_id   INT           = NULL,
    @result_msg      NVARCHAR(500) = NULL OUTPUT,
    @success         BIT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @success    = 0;
    SET @result_msg = '';

    DECLARE
        @league_name    NVARCHAR(150),
        @matches_found  INT = 0,
        @teams_updated  INT = 0;

    -- -------------------------------------------------------------------------
    -- Validate league
    -- -------------------------------------------------------------------------
    SELECT @league_name = name
    FROM comp.league
    WHERE league_id = @league_id;

    IF @league_name IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: League ID ', @league_id, ' does not exist.');
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY

        -- -------------------------------------------------------------------------
        -- STEP 1: Rebuild team_standing from completed matches
        -- Delete existing rows for this league, recalculate from match history
        -- -------------------------------------------------------------------------
        DELETE FROM comp.team_standing
        WHERE league_id = @league_id;

        -- Aggregate all completed match results for teams in this league
        ;WITH match_results AS (
            SELECT
                m.tournament_id,
                tn.league_id,
                -- Winner perspective
                m.winner_id                             AS team_id,
                1                                       AS is_win,
                0                                       AS is_loss,
                -- Map scores from winner's perspective
                CASE WHEN m.winner_id = m.team_a_id
                     THEN m.score_a ELSE m.score_b END  AS maps_won,
                CASE WHEN m.winner_id = m.team_a_id
                     THEN m.score_b ELSE m.score_a END  AS maps_lost
            FROM comp.match m
            JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
            WHERE m.status = 'Completed'
              AND tn.league_id = @league_id
              AND m.winner_id IS NOT NULL

            UNION ALL

            -- Loser perspective (same matches, other team)
            SELECT
                m.tournament_id,
                tn.league_id,
                CASE WHEN m.winner_id = m.team_a_id
                     THEN m.team_b_id ELSE m.team_a_id END AS team_id,
                0,
                1,
                CASE WHEN m.winner_id = m.team_a_id
                     THEN m.score_b ELSE m.score_a END,
                CASE WHEN m.winner_id = m.team_a_id
                     THEN m.score_a ELSE m.score_b END
            FROM comp.match m
            JOIN comp.tournament tn ON tn.tournament_id = m.tournament_id
            WHERE m.status = 'Completed'
              AND tn.league_id = @league_id
              AND m.winner_id IS NOT NULL
        ),
        standing_agg AS (
            SELECT
                league_id,
                team_id,
                SUM(is_win)     AS wins,
                SUM(is_loss)    AS losses,
                0               AS draws,
                SUM(is_win) * 3 AS points,
                SUM(maps_won)   AS maps_won,
                SUM(maps_lost)  AS maps_lost
            FROM match_results
            GROUP BY league_id, team_id
        )
        INSERT INTO comp.team_standing
            (league_id, team_id, wins, losses, draws, points, maps_won, maps_lost, updated_at)
        SELECT
            league_id, team_id, wins, losses, draws, points, maps_won, maps_lost,
            SYSUTCDATETIME()
        FROM standing_agg;

        SET @teams_updated = @@ROWCOUNT;

        -- -------------------------------------------------------------------------
        -- STEP 2: Recalculate player ELO for @tournament_id (if provided)
        -- Uses a cursor to walk matches in chronological order,
        -- applying K=32 Elo updates after each match.
        -- -------------------------------------------------------------------------
        IF @tournament_id IS NOT NULL
        BEGIN
            DECLARE
                @cur_match_id    INT,
                @cur_player_id   INT,
                @cur_mvp         BIT,
                @cur_kills       SMALLINT,
                @cur_deaths      SMALLINT,
                @avg_opponent_elo DECIMAL(8,2),
                @player_elo      DECIMAL(8,2),
                @expected        DECIMAL(8,4),
                @new_elo         DECIMAL(8,2),
                @k_factor        DECIMAL(5,1) = 32.0,
                @win_flag        TINYINT;

            -- Reset ELO for all players in this tournament to 1000
            DELETE FROM comp.player_rating
            WHERE tournament_id = @tournament_id;

            -- Seed starting ratings at 1000
            INSERT INTO comp.player_rating
                (player_id, tournament_id, elo_score, games_played, win_rate, calculated_at)
            SELECT DISTINCT
                ps.player_id,
                @tournament_id,
                1000.00,
                0,
                0,
                SYSUTCDATETIME()
            FROM comp.player_stat ps
            JOIN comp.match m ON m.match_id = ps.match_id
            WHERE m.tournament_id = @tournament_id;

            -- Walk matches chronologically, update ELO per player per match
            DECLARE elo_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT ps.match_id, ps.player_id
                FROM comp.player_stat ps
                JOIN comp.match m ON m.match_id = ps.match_id
                WHERE m.tournament_id = @tournament_id
                  AND m.status = 'Completed'
                ORDER BY ps.match_id, ps.player_id;

            OPEN elo_cursor;
            FETCH NEXT FROM elo_cursor INTO @cur_match_id, @cur_player_id;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Was this player on the winning team?
                SELECT @win_flag =
                    CASE WHEN p.team_id = m.winner_id THEN 1 ELSE 0 END
                FROM comp.player p
                JOIN comp.match  m ON m.match_id = @cur_match_id
                WHERE p.player_id = @cur_player_id;

                -- Current ELO
                SELECT @player_elo = elo_score
                FROM comp.player_rating
                WHERE player_id = @cur_player_id
                  AND tournament_id = @tournament_id;

                -- Average ELO of opposing team's players in this match
                SELECT @avg_opponent_elo = AVG(pr.elo_score)
                FROM comp.player_stat  ops_ps
                JOIN comp.player       op   ON op.player_id = ops_ps.player_id
                JOIN comp.match        m    ON m.match_id   = ops_ps.match_id
                JOIN comp.player_rating pr  ON pr.player_id = ops_ps.player_id
                                           AND pr.tournament_id = @tournament_id
                WHERE ops_ps.match_id = @cur_match_id
                  AND (
                    (m.winner_id = m.team_a_id AND op.team_id = m.team_b_id)
                    OR
                    (m.winner_id = m.team_b_id AND op.team_id = m.team_a_id)
                  );

                IF @avg_opponent_elo IS NULL SET @avg_opponent_elo = 1000.00;

                -- Elo formula
                SET @expected = 1.0 / (1.0 + POWER(10.0, (@avg_opponent_elo - @player_elo) / 400.0));
                SET @new_elo  = @player_elo + @k_factor * (@win_flag - @expected);

                UPDATE comp.player_rating
                SET
                    elo_score    = @new_elo,
                    games_played = games_played + 1,
                    calculated_at = SYSUTCDATETIME()
                WHERE player_id    = @cur_player_id
                  AND tournament_id = @tournament_id;

                FETCH NEXT FROM elo_cursor INTO @cur_match_id, @cur_player_id;
            END

            CLOSE elo_cursor;
            DEALLOCATE elo_cursor;

            -- Assign rank positions after all ELO updates
            UPDATE pr
            SET rank_position = ranked.rn
            FROM comp.player_rating pr
            JOIN (
                SELECT player_id,
                       tournament_id,
                       ROW_NUMBER() OVER (
                           PARTITION BY tournament_id
                           ORDER BY elo_score DESC
                       ) AS rn
                FROM comp.player_rating
                WHERE tournament_id = @tournament_id
            ) ranked
                ON ranked.player_id     = pr.player_id
               AND ranked.tournament_id = pr.tournament_id;

            -- Update win rates
            UPDATE pr
            SET win_rate = CASE
                WHEN ps_agg.total_matches = 0 THEN 0
                ELSE CAST(ps_agg.wins AS DECIMAL(5,2)) / ps_agg.total_matches * 100
            END
            FROM comp.player_rating pr
            JOIN (
                SELECT
                    ps.player_id,
                    COUNT(DISTINCT m.match_id)                           AS total_matches,
                    SUM(CASE WHEN p.team_id = m.winner_id THEN 1 ELSE 0 END) AS wins
                FROM comp.player_stat ps
                JOIN comp.match  m ON m.match_id  = ps.match_id
                JOIN comp.player p ON p.player_id = ps.player_id
                WHERE m.tournament_id = @tournament_id
                  AND m.status = 'Completed'
                GROUP BY ps.player_id
            ) ps_agg ON ps_agg.player_id = pr.player_id
            WHERE pr.tournament_id = @tournament_id;

        END -- ELO block

        -- Audit entry
        INSERT INTO audit.log
            (schema_name, table_name, operation, record_id, new_value, changed_by, app_context)
        VALUES
            ('comp', 'team_standing', 'MERGE', @league_id,
             CONCAT('league_id=', @league_id, ' | teams_updated=', @teams_updated),
             SYSTEM_USER, 'usp_calculate_standings');

        COMMIT TRANSACTION;

        SET @success    = 1;
        SET @result_msg = CONCAT(
            'SUCCESS: Standings recalculated for league "', @league_name, '" — ',
            @teams_updated, ' team rows upserted.',
            CASE WHEN @tournament_id IS NOT NULL
                 THEN CONCAT(' ELO ratings updated for tournament ', @tournament_id, '.')
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
-- DECLARE @msg NVARCHAR(500), @ok BIT;
-- EXEC comp.usp_calculate_standings
--     @league_id     = 1,
--     @tournament_id = 3,
--     @result_msg    = @msg OUTPUT,
--     @success       = @ok  OUTPUT;
-- SELECT @ok AS success, @msg AS message;
-- =============================================================================

PRINT '03_usp_calculate_standings: procedure created.';
GO
