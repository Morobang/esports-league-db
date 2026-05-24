-- =============================================================================
-- FILE:    05_usp_generate_player_report.sql
-- PURPOSE: Generate a complete player performance report across all tournaments
--          Returns multiple result sets — career stats, per-tournament breakdown,
--          best match, and contract status
-- DEPENDS: 04_views/
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- comp.usp_generate_player_report
--
-- Returns 4 result sets for a given player:
--   RS1 — Player profile + current contract summary
--   RS2 — Career aggregate stats (totals and averages across all matches)
--   RS3 — Per-tournament breakdown (from vw_player_leaderboard)
--   RS4 — Top 3 individual match performances by damage dealt
--
-- Parameters:
--   @player_id      INT           - player to report on
--   @result_msg     NVARCHAR OUT
--   @success        BIT OUT
-- =============================================================================

CREATE OR ALTER PROCEDURE comp.usp_generate_player_report
    @player_id   INT,
    @result_msg  NVARCHAR(400) = NULL OUTPUT,
    @success     BIT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @success    = 0;
    SET @result_msg = '';

    -- Validate player exists
    IF NOT EXISTS (SELECT 1 FROM comp.player WHERE player_id = @player_id)
    BEGIN
        SET @result_msg = CONCAT('ERROR: Player ID ', @player_id, ' does not exist.');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- RS1: Player profile and current contract
    -- -------------------------------------------------------------------------
    SELECT
        p.player_id,
        p.username,
        p.real_name,
        p.nationality,
        p.role,
        p.status                                    AS player_status,
        p.joined_at,
        t.name                                      AS current_team,
        t.tag                                       AS team_tag,
        r.name                                      AS team_region,
        -- Contract details
        c.contract_id,
        c.salary_monthly,
        c.currency                                  AS contract_currency,
        c.start_date                                AS contract_start,
        c.end_date                                  AS contract_end,
        DATEDIFF(DAY, GETUTCDATE(), c.end_date)     AS days_until_expiry,
        c.buyout_clause,
        c.status                                    AS contract_status,
        -- Career ELO (best rating across all tournaments)
        (
            SELECT MAX(elo_score)
            FROM comp.player_rating
            WHERE player_id = @player_id
        )                                           AS peak_elo,
        (
            SELECT COUNT(DISTINCT tournament_id)
            FROM comp.player_rating
            WHERE player_id = @player_id
        )                                           AS tournaments_played
    FROM comp.player p
    LEFT JOIN comp.team     t ON t.team_id    = p.team_id
    LEFT JOIN comp.region   r ON r.region_id  = t.region_id
    LEFT JOIN comp.contract c ON c.player_id  = p.player_id
                              AND c.status    = 'Active'
    WHERE p.player_id = @player_id;

    -- -------------------------------------------------------------------------
    -- RS2: Career aggregate stats
    -- -------------------------------------------------------------------------
    SELECT
        @player_id                                  AS player_id,
        COUNT(DISTINCT ps.match_id)                 AS total_matches,
        SUM(ps.kills)                               AS career_kills,
        SUM(ps.deaths)                              AS career_deaths,
        SUM(ps.assists)                             AS career_assists,
        ROUND(
            CASE WHEN SUM(ps.deaths) = 0
                 THEN CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT)
                 ELSE CAST(SUM(ps.kills) + SUM(ps.assists) AS FLOAT) / SUM(ps.deaths)
            END, 2
        )                                           AS career_kda,
        SUM(ps.damage_dealt)                        AS career_damage,
        SUM(ps.healing_done)                        AS career_healing,
        SUM(CAST(ps.mvp_flag AS INT))               AS career_mvps,
        SUM(CAST(ps.first_blood AS INT))            AS career_first_bloods,
        ROUND(AVG(CAST(ps.kills AS FLOAT)), 1)      AS avg_kills_per_match,
        ROUND(AVG(CAST(ps.deaths AS FLOAT)), 1)     AS avg_deaths_per_match,
        ROUND(AVG(CAST(ps.damage_dealt AS FLOAT)),0)AS avg_damage_per_match,
        -- Win rate across all matches
        ROUND(
            100.0 * SUM(CASE WHEN p.team_id = m.winner_id THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(DISTINCT ps.match_id), 0),
            1
        )                                           AS career_win_rate_pct
    FROM comp.player_stat ps
    JOIN comp.match  m ON m.match_id  = ps.match_id
    JOIN comp.player p ON p.player_id = ps.player_id
    WHERE ps.player_id = @player_id
      AND m.status = 'Completed';

    -- -------------------------------------------------------------------------
    -- RS3: Per-tournament breakdown (uses vw_player_leaderboard)
    -- -------------------------------------------------------------------------
    SELECT
        tournament_name,
        game_name,
        team_name,
        matches_played,
        total_kills,
        total_deaths,
        total_assists,
        overall_kda,
        total_damage,
        mvp_count,
        first_bloods,
        elo_score,
        elo_rank,
        kills_rank,
        kda_rank
    FROM comp.vw_player_leaderboard
    WHERE player_id = @player_id
    ORDER BY tournament_name;

    -- -------------------------------------------------------------------------
    -- RS4: Top 3 individual match performances (by damage dealt)
    -- -------------------------------------------------------------------------
    SELECT TOP 3
        ps.match_id,
        m.stage,
        m.played_at,
        tn.name                                     AS tournament_name,
        ta.name                                     AS team_a,
        tb.name                                     AS team_b,
        tw.name                                     AS winner,
        CONCAT(m.score_a, '–', m.score_b)           AS series_score,
        ps.kills,
        ps.deaths,
        ps.assists,
        ps.damage_dealt,
        ps.healing_done,
        ps.mvp_flag,
        ps.first_blood
    FROM comp.player_stat ps
    JOIN comp.match      m   ON m.match_id       = ps.match_id
    JOIN comp.tournament tn  ON tn.tournament_id = m.tournament_id
    JOIN comp.team       ta  ON ta.team_id       = m.team_a_id
    JOIN comp.team       tb  ON tb.team_id       = m.team_b_id
    LEFT JOIN comp.team  tw  ON tw.team_id       = m.winner_id
    WHERE ps.player_id = @player_id
      AND m.status = 'Completed'
    ORDER BY ps.damage_dealt DESC;

    SET @success    = 1;
    SET @result_msg = CONCAT('SUCCESS: Report generated for player ID ', @player_id, '.');
END;
GO

-- =============================================================================
-- Usage example:
-- DECLARE @msg NVARCHAR(400), @ok BIT;
-- EXEC comp.usp_generate_player_report
--     @player_id  = 41,      -- ApexHunter
--     @result_msg = @msg OUTPUT,
--     @success    = @ok  OUTPUT;
-- SELECT @ok AS success, @msg AS message;
-- =============================================================================

PRINT '05_usp_generate_player_report: procedure created.';
GO
