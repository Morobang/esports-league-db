-- =============================================================================
-- FILE:    04_usp_issue_ticket.sql
-- PURPOSE: Issue tickets to a fan — validates seat availability,
--          creates the order, and updates seats_sold atomically
-- DEPENDS: 03_usp_calculate_standings.sql
-- =============================================================================

USE EsportsLeague;
GO

-- =============================================================================
-- ops.usp_issue_ticket
--
-- Handles a ticket purchase for a fan. In one transaction:
--   1. Validates fan exists and is active
--   2. Validates tier exists, event is Scheduled/Live, sale window is open
--   3. Checks enough seats are available (with row-level lock via UPDLOCK)
--   4. Creates the ticket_order record
--   5. Increments ticket_tier.seats_sold
--   6. Returns order_id and confirmation details
--
-- Parameters:
--   @fan_id         INT           - purchasing fan
--   @tier_id        INT           - ticket tier to purchase
--   @quantity       TINYINT       - number of seats (1-10)
--   @payment_ref    NVARCHAR      - external payment reference
--   @order_id       INT OUT       - created order ID
--   @result_msg     NVARCHAR OUT
--   @success        BIT OUT
-- =============================================================================

CREATE OR ALTER PROCEDURE ops.usp_issue_ticket
    @fan_id       INT,
    @tier_id      INT,
    @quantity     TINYINT       = 1,
    @payment_ref  NVARCHAR(100) = NULL,
    @order_id     INT           = NULL OUTPUT,
    @result_msg   NVARCHAR(400) = NULL OUTPUT,
    @success      BIT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @success  = 0;
    SET @order_id = NULL;
    SET @result_msg = '';

    DECLARE
        @fan_active     BIT,
        @fan_username   NVARCHAR(60),
        @tier_name      NVARCHAR(50),
        @tier_price     DECIMAL(10,2),
        @tier_currency  NVARCHAR(5),
        @total_seats    INT,
        @seats_sold     INT,
        @seats_avail    INT,
        @sale_start     DATETIME2(0),
        @sale_end       DATETIME2(0),
        @event_status   NVARCHAR(20),
        @event_name     NVARCHAR(200),
        @total_amount   DECIMAL(12,2),
        @now            DATETIME2(0) = SYSUTCDATETIME();

    -- -------------------------------------------------------------------------
    -- 1. Validate fan
    -- -------------------------------------------------------------------------
    SELECT @fan_username = username, @fan_active = is_active
    FROM ops.fan
    WHERE fan_id = @fan_id;

    IF @fan_username IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: Fan ID ', @fan_id, ' not found.');
        RETURN;
    END

    IF @fan_active = 0
    BEGIN
        SET @result_msg = CONCAT('ERROR: Fan "', @fan_username, '" account is inactive.');
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 2. Validate quantity
    -- -------------------------------------------------------------------------
    IF @quantity < 1 OR @quantity > 10
    BEGIN
        SET @result_msg = 'ERROR: Quantity must be between 1 and 10.';
        RETURN;
    END

    -- -------------------------------------------------------------------------
    -- 3. Validate tier and event
    -- -------------------------------------------------------------------------
    SELECT
        @tier_name    = tt.tier_name,
        @tier_price   = tt.price,
        @tier_currency= tt.currency,
        @total_seats  = tt.total_seats,
        @seats_sold   = tt.seats_sold,
        @sale_start   = tt.sale_start,
        @sale_end     = tt.sale_end,
        @event_status = e.status,
        @event_name   = e.name
    FROM ops.ticket_tier tt
    JOIN ops.event       e ON e.event_id = tt.event_id
    WHERE tt.tier_id = @tier_id;

    IF @tier_name IS NULL
    BEGIN
        SET @result_msg = CONCAT('ERROR: Ticket tier ID ', @tier_id, ' not found.');
        RETURN;
    END

    IF @event_status NOT IN ('Scheduled', 'Live')
    BEGIN
        SET @result_msg = CONCAT('ERROR: Event "', @event_name,
                                 '" is ', @event_status, ' — tickets unavailable.');
        RETURN;
    END

    IF @sale_start IS NOT NULL AND @now < @sale_start
    BEGIN
        SET @result_msg = CONCAT('ERROR: Ticket sales for "', @tier_name,
                                 '" open on ', CONVERT(NVARCHAR, @sale_start, 120), '.');
        RETURN;
    END

    IF @sale_end IS NOT NULL AND @now > @sale_end
    BEGIN
        SET @result_msg = CONCAT('ERROR: Ticket sales for "', @tier_name, '" have closed.');
        RETURN;
    END

    SET @seats_avail = @total_seats - @seats_sold;

    IF @seats_avail < @quantity
    BEGIN
        SET @result_msg = CONCAT('ERROR: Only ', @seats_avail,
                                 ' seat(s) remaining in "', @tier_name, '".',
                                 CASE WHEN @seats_avail = 0 THEN ' SOLD OUT.' ELSE '' END);
        RETURN;
    END

    SET @total_amount = @tier_price * @quantity;

    -- -------------------------------------------------------------------------
    -- 4. Issue the ticket atomically
    --    UPDLOCK on ticket_tier prevents concurrent over-selling
    -- -------------------------------------------------------------------------
    BEGIN TRANSACTION;
    BEGIN TRY

        -- Re-check seats with UPDLOCK (prevents race condition)
        SELECT @seats_avail = total_seats - seats_sold
        FROM ops.ticket_tier WITH (UPDLOCK, ROWLOCK)
        WHERE tier_id = @tier_id;

        IF @seats_avail < @quantity
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_msg = CONCAT('ERROR: Seats no longer available in "', @tier_name,
                                     '" (concurrent purchase detected).');
            RETURN;
        END

        -- Create order
        INSERT INTO ops.ticket_order
            (fan_id, tier_id, quantity, unit_price, total_amount, currency,
             status, payment_ref, ordered_at, updated_at)
        VALUES
            (@fan_id, @tier_id, @quantity, @tier_price, @total_amount, @tier_currency,
             'Confirmed', @payment_ref, @now, @now);

        SET @order_id = SCOPE_IDENTITY();

        -- Increment seats_sold
        UPDATE ops.ticket_tier
        SET seats_sold = seats_sold + @quantity
        WHERE tier_id = @tier_id;

        -- Audit
        INSERT INTO audit.log
            (schema_name, table_name, operation, record_id, new_value, changed_by, app_context)
        VALUES
            ('ops', 'ticket_order', 'INSERT', @order_id,
             CONCAT('fan_id=', @fan_id, ' | tier_id=', @tier_id,
                    ' | qty=', @quantity, ' | total=', @total_amount, ' ', @tier_currency),
             SYSTEM_USER, 'usp_issue_ticket');

        COMMIT TRANSACTION;

        SET @success = 1;
        SET @result_msg = CONCAT(
            'SUCCESS: Order #', @order_id, ' confirmed — ',
            @quantity, ' x "', @tier_name, '" for "', @event_name, '".',
            ' Total: ', @tier_currency, ' ', FORMAT(@total_amount, 'N2'), '.'
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
-- DECLARE @oid INT, @msg NVARCHAR(400), @ok BIT;
-- EXEC ops.usp_issue_ticket
--     @fan_id      = 1,
--     @tier_id     = 14,
--     @quantity    = 2,
--     @payment_ref = 'PAY-TEST-001',
--     @order_id    = @oid OUTPUT,
--     @result_msg  = @msg OUTPUT,
--     @success     = @ok  OUTPUT;
-- SELECT @ok AS success, @oid AS order_id, @msg AS message;
-- =============================================================================

PRINT '04_usp_issue_ticket: procedure created.';
GO
