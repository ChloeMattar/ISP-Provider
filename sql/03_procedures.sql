/* =====================================================================
   03_procedures.sql : stored procedures (the only thing the app may call)

   Conventions used everywhere:
   - SET NOCOUNT ON : do not send "(1 row affected)" messages to the app.
   - THROW 5xxxx    : our own business errors. Numbers >= 50000 are free
                      for user errors; the API shows their message to the user.
   - Every procedure ends with a SELECT so the app always reads rows back.
   ===================================================================== */
USE ISPManagement;
GO
-- Required for procedures that touch a table with a filtered index.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* =====================================================================
   CUSTOMERS
   ===================================================================== */

-- Search by name (contains) or phone (starts with). NULL = list everybody.
CREATE OR ALTER PROCEDURE dbo.usp_SearchCustomers
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (50)
           c.CustomerID, c.FullName, c.Phone, c.Email, c.City, c.Status,
           dbo.fn_CustomerBalance(c.CustomerID) AS Balance
    FROM dbo.Customers AS c
    WHERE @Search IS NULL
       OR c.FullName LIKE '%' + @Search + '%'
       OR c.Phone    LIKE @Search + '%'
    ORDER BY c.FullName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AddCustomer
    @FullName NVARCHAR(100),
    @Phone    VARCHAR(20),
    @Email    VARCHAR(100) = NULL,
    @City     NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(@FullName)) = '' OR LTRIM(RTRIM(@Phone)) = '' OR LTRIM(RTRIM(@City)) = ''
        THROW 50010, 'Name, phone and city are required.', 1;

    -- A duplicate phone is refused by the UNIQUE constraint UQ_Customers_Phone.
    INSERT INTO dbo.Customers (FullName, Phone, Email, City)
    VALUES (@FullName, @Phone, @Email, @City);

    -- SCOPE_IDENTITY(): the ID that this INSERT just generated
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS CustomerID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpdateCustomer
    @CustomerID INT,
    @FullName   NVARCHAR(100),
    @Phone      VARCHAR(20),
    @Email      VARCHAR(100) = NULL,
    @City       NVARCHAR(50),
    @Status     VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(@FullName)) = '' OR LTRIM(RTRIM(@Phone)) = '' OR LTRIM(RTRIM(@City)) = ''
        THROW 50010, 'Name, phone and city are required.', 1;

    UPDATE dbo.Customers
    SET FullName = @FullName,
        Phone    = @Phone,
        Email    = @Email,
        City     = @City,
        Status   = @Status
    WHERE CustomerID = @CustomerID;

    -- @@ROWCOUNT: number of rows changed by the previous statement
    IF @@ROWCOUNT = 0
        THROW 50011, 'Customer not found.', 1;

    SELECT @CustomerID AS CustomerID;
END;
GO

/* =====================================================================
   PLANS
   ===================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_GetPlans
AS
BEGIN
    SET NOCOUNT ON;

    SELECT PlanID, PlanName, SpeedMbps, QuotaGB, MonthlyPrice, OveragePricePerGB, IsActive
    FROM dbo.Plans
    ORDER BY MonthlyPrice;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AddPlan
    @PlanName          NVARCHAR(50),
    @SpeedMbps         INT,
    @QuotaGB           INT,
    @MonthlyPrice      DECIMAL(10,2),
    @OveragePricePerGB DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Wrong numbers (0, negative) are refused by the CHECK constraints.
    INSERT INTO dbo.Plans (PlanName, SpeedMbps, QuotaGB, MonthlyPrice, OveragePricePerGB)
    VALUES (@PlanName, @SpeedMbps, @QuotaGB, @MonthlyPrice, @OveragePricePerGB);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS PlanID;
END;
GO

-- A plan is never deleted (old subscriptions point to it): we set IsActive = 0.
CREATE OR ALTER PROCEDURE dbo.usp_UpdatePlan
    @PlanID            INT,
    @PlanName          NVARCHAR(50),
    @SpeedMbps         INT,
    @QuotaGB           INT,
    @MonthlyPrice      DECIMAL(10,2),
    @OveragePricePerGB DECIMAL(10,2),
    @IsActive          BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Plans
    SET PlanName          = @PlanName,
        SpeedMbps         = @SpeedMbps,
        QuotaGB           = @QuotaGB,
        MonthlyPrice      = @MonthlyPrice,
        OveragePricePerGB = @OveragePricePerGB,
        IsActive          = @IsActive
    WHERE PlanID = @PlanID;

    IF @@ROWCOUNT = 0
        THROW 50015, 'Plan not found.', 1;

    SELECT @PlanID AS PlanID;
END;
GO

/* =====================================================================
   SUBSCRIPTIONS
   ===================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_GetSubscriptions
    @CustomerID INT         = NULL,     -- NULL = all customers
    @Status     VARCHAR(10) = NULL      -- NULL = all statuses
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (200)
           s.SubscriptionID, s.CustomerID, c.FullName,
           s.PlanID, p.PlanName, p.MonthlyPrice,
           s.StartDate, s.EndDate, s.Status
    FROM dbo.Subscriptions AS s
    JOIN dbo.Customers AS c ON c.CustomerID = s.CustomerID
    JOIN dbo.Plans     AS p ON p.PlanID     = s.PlanID
    WHERE (@CustomerID IS NULL OR s.CustomerID = @CustomerID)
      AND (@Status     IS NULL OR s.Status     = @Status)
    ORDER BY s.SubscriptionID DESC;
END;
GO

-- Start a new subscription today.
CREATE OR ALTER PROCEDURE dbo.usp_ActivateSubscription
    @CustomerID INT,
    @PlanID     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID AND Status = 'Active')
        THROW 50020, 'Customer not found or inactive.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Plans WHERE PlanID = @PlanID AND IsActive = 1)
        THROW 50021, 'Plan not found or no longer sold.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Subscriptions
               WHERE CustomerID = @CustomerID AND Status IN ('Active', 'Suspended'))
        THROW 50022, 'This customer already has an open subscription.', 1;

    -- If two users activate for the same customer at the same instant, both can
    -- pass the IF above. The filtered unique index UX_Subscriptions_OneOpenPerCustomer
    -- then refuses the second INSERT: the rule cannot be broken.
    INSERT INTO dbo.Subscriptions (CustomerID, PlanID, StartDate)
    VALUES (@CustomerID, @PlanID, CAST(GETDATE() AS DATE));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS SubscriptionID;
END;
GO

-- Move a subscription to another plan. The trigger writes the audit row.
CREATE OR ALTER PROCEDURE dbo.usp_ChangePlan
    @SubscriptionID INT,
    @NewPlanID      INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Plans WHERE PlanID = @NewPlanID AND IsActive = 1)
        THROW 50021, 'Plan not found or no longer sold.', 1;

    UPDATE dbo.Subscriptions
    SET PlanID = @NewPlanID
    WHERE SubscriptionID = @SubscriptionID
      AND Status <> 'Cancelled'
      AND PlanID <> @NewPlanID;

    IF @@ROWCOUNT = 0
        THROW 50023, 'Subscription not found, cancelled, or already on this plan.', 1;

    SELECT @SubscriptionID AS SubscriptionID;
END;
GO

-- Suspend, resume (back to Active) or cancel. Cancelled is final.
CREATE OR ALTER PROCEDURE dbo.usp_SetSubscriptionStatus
    @SubscriptionID INT,
    @NewStatus      VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentStatus VARCHAR(10);

    SELECT @CurrentStatus = Status
    FROM dbo.Subscriptions
    WHERE SubscriptionID = @SubscriptionID;

    IF @CurrentStatus IS NULL
        THROW 50024, 'Subscription not found.', 1;

    IF @CurrentStatus = 'Cancelled'
        THROW 50025, 'A cancelled subscription is closed. Activate a new one instead.', 1;

    IF @NewStatus NOT IN ('Active', 'Suspended', 'Cancelled')
        THROW 50026, 'Status must be Active, Suspended or Cancelled.', 1;

    IF @NewStatus = @CurrentStatus
        THROW 50027, 'The subscription already has this status.', 1;

    UPDATE dbo.Subscriptions
    SET Status  = @NewStatus,
        -- cancelling closes the subscription today; other statuses keep it open
        EndDate = CASE WHEN @NewStatus = 'Cancelled' THEN CAST(GETDATE() AS DATE) ELSE NULL END
    WHERE SubscriptionID = @SubscriptionID;

    SELECT @SubscriptionID AS SubscriptionID;
END;
GO

/* =====================================================================
   BILLING
   ===================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_GetInvoices
    @OnlyUnpaid BIT = 1,        -- 1 = only invoices with money still due
    @CustomerID INT = NULL      -- NULL = all customers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (200)
           i.InvoiceID, i.SubscriptionID, s.CustomerID, c.FullName,
           i.PeriodStart, i.Amount, i.AmountPaid,
           i.Amount - i.AmountPaid AS Balance,
           i.Status, i.DueDate
    FROM dbo.Invoices AS i
    JOIN dbo.Subscriptions AS s ON s.SubscriptionID = i.SubscriptionID
    JOIN dbo.Customers     AS c ON c.CustomerID     = s.CustomerID
    WHERE (@OnlyUnpaid = 0     OR i.Status IN ('Unpaid', 'Partial'))
      AND (@CustomerID IS NULL OR s.CustomerID = @CustomerID)
    ORDER BY i.PeriodStart DESC, i.InvoiceID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetPayments
    @InvoiceID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT PaymentID, InvoiceID, Amount, Method, PaidAt
    FROM dbo.Payments
    WHERE InvoiceID = @InvoiceID
    ORDER BY PaidAt;
END;
GO

/* ---------------------------------------------------------------------
   usp_GenerateMonthlyInvoices           (TRANSACTION #1)
   Creates one invoice for every subscription that was open during the
   month:  amount = plan price + overage charge.
   All invoices of the month are created together or not at all.
   Safe to run twice: subscriptions already billed are skipped.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.usp_GenerateMonthlyInvoices
    @Year  INT,
    @Month INT
AS
BEGIN
    SET NOCOUNT ON;
    -- XACT_ABORT: if anything fails (even a timeout from the app),
    -- SQL Server rolls the whole transaction back by itself.
    SET XACT_ABORT ON;

    IF @Month < 1 OR @Month > 12 OR @Year < 2000 OR @Year > 2100
        THROW 50040, 'Invalid year or month.', 1;

    DECLARE @PeriodStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @PeriodEnd   DATE = EOMONTH(@PeriodStart);
    DECLARE @Created     INT;

    IF @PeriodEnd >= CAST(GETDATE() AS DATE)
        THROW 50041, 'This month is not finished yet: it cannot be billed.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Invoices (SubscriptionID, PeriodStart, PeriodEnd, Amount, DueDate)
        SELECT s.SubscriptionID,
               @PeriodStart,
               @PeriodEnd,
               p.MonthlyPrice
                 + dbo.fn_OverageCharge(ISNULL(u.TotalMB, 0), p.QuotaGB, p.OveragePricePerGB),
               DATEADD(DAY, 10, @PeriodEnd)          -- 10 days to pay
        FROM dbo.Subscriptions AS s
        JOIN dbo.Plans AS p ON p.PlanID = s.PlanID
        -- usage of the month, one line per subscription (computed in ONE pass
        -- over the large table, not once per subscription)
        LEFT JOIN (
            SELECT SubscriptionID,
                   SUM(CAST(DownloadMB AS BIGINT) + UploadMB) AS TotalMB
            FROM dbo.UsageRecords
            WHERE UsageDate >= @PeriodStart
              AND UsageDate <= @PeriodEnd
            GROUP BY SubscriptionID
        ) AS u ON u.SubscriptionID = s.SubscriptionID
        -- the subscription was open at some point during the month
        WHERE s.StartDate <= @PeriodEnd
          AND (s.EndDate IS NULL OR s.EndDate >= @PeriodStart)
          -- skip subscriptions already billed for this month
          AND NOT EXISTS (SELECT 1
                          FROM dbo.Invoices AS i
                          WHERE i.SubscriptionID = s.SubscriptionID
                            AND i.PeriodStart    = @PeriodStart);

        SET @Created = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Something failed (for example another user billed the same month at
        -- the same time and UQ_Invoices_Subscription_Period refused our rows).
        -- Undo everything, then pass the original error to the caller.
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Created AS InvoicesCreated;
END;
GO

/* ---------------------------------------------------------------------
   usp_RecordPayment                     (TRANSACTION #2)
   Two steps that must succeed or fail together:
     1. insert the payment
     2. update the invoice (AmountPaid and Status)
   Two cashiers paying the same invoice at the same time must not overpay it.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.usp_RecordPayment
    @InvoiceID INT,
    @Amount    DECIMAL(10,2),
    @Method    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Balance DECIMAL(10,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- UPDLOCK: "I am reading this row because I am going to update it".
        -- A second user running this procedure for the same invoice WAITS here
        -- until we commit, then reads the new balance, not the old one.
        SELECT @Balance = Amount - AmountPaid
        FROM dbo.Invoices WITH (UPDLOCK)
        WHERE InvoiceID = @InvoiceID;

        IF @Balance IS NULL
            THROW 50030, 'Invoice not found.', 1;

        IF @Amount <= 0
            THROW 50031, 'The payment amount must be greater than zero.', 1;

        IF @Amount > @Balance
            THROW 50032, 'The payment is larger than the remaining balance.', 1;

        IF @Method NOT IN ('Cash', 'Card', 'Transfer')
            THROW 50033, 'Method must be Cash, Card or Transfer.', 1;

        INSERT INTO dbo.Payments (InvoiceID, Amount, Method)
        VALUES (@InvoiceID, @Amount, @Method);

        UPDATE dbo.Invoices
        SET AmountPaid = AmountPaid + @Amount,
            Status     = CASE WHEN AmountPaid + @Amount = Amount THEN 'Paid'
                              ELSE 'Partial' END
        WHERE InvoiceID = @InvoiceID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Any error (ours or SQL Server's): undo both steps, re-raise the error.
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT InvoiceID, Amount, AmountPaid, Amount - AmountPaid AS Balance, Status
    FROM dbo.Invoices
    WHERE InvoiceID = @InvoiceID;
END;
GO

/* =====================================================================
   USAGE (the large table)
   ===================================================================== */

-- KEY QUERY 1: daily usage of one subscription between two dates.
CREATE OR ALTER PROCEDURE dbo.usp_GetDailyUsage
    @SubscriptionID INT,
    @FromDate       DATE,
    @ToDate         DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT UsageDate, DownloadMB, UploadMB
    FROM dbo.UsageRecords
    WHERE SubscriptionID = @SubscriptionID
      AND UsageDate >= @FromDate
      AND UsageDate <= @ToDate
    ORDER BY UsageDate;
END;
GO

-- Month by month totals of one subscription, next to the plan quota.
CREATE OR ALTER PROCEDURE dbo.usp_GetUsageSummary
    @SubscriptionID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DATEFROMPARTS(YEAR(u.UsageDate), MONTH(u.UsageDate), 1) AS MonthStart,
           CAST(SUM(CAST(u.DownloadMB AS BIGINT)) / 1024.0 AS DECIMAL(12,2)) AS DownloadGB,
           CAST(SUM(CAST(u.UploadMB   AS BIGINT)) / 1024.0 AS DECIMAL(12,2)) AS UploadGB,
           CAST(SUM(CAST(u.DownloadMB AS BIGINT) + u.UploadMB) / 1024.0 AS DECIMAL(12,2)) AS TotalGB,
           p.QuotaGB
    FROM dbo.UsageRecords AS u
    JOIN dbo.Subscriptions AS s ON s.SubscriptionID = u.SubscriptionID
    JOIN dbo.Plans         AS p ON p.PlanID         = s.PlanID
    WHERE u.SubscriptionID = @SubscriptionID
    GROUP BY YEAR(u.UsageDate), MONTH(u.UsageDate), p.QuotaGB
    ORDER BY MonthStart;
END;
GO

-- KEY QUERY 2: the heaviest users of a month.
CREATE OR ALTER PROCEDURE dbo.usp_GetTopConsumers
    @Year  INT,
    @Month INT,
    @Top   INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @Month < 1 OR @Month > 12 OR @Year < 2000 OR @Year > 2100
        THROW 50040, 'Invalid year or month.', 1;

    IF @Top < 1 OR @Top > 100
        THROW 50042, 'Top must be between 1 and 100.', 1;

    DECLARE @PeriodStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @PeriodEnd   DATE = EOMONTH(@PeriodStart);

    SELECT TOP (@Top)
           u.SubscriptionID, c.FullName, p.PlanName, p.QuotaGB,
           CAST(SUM(CAST(u.DownloadMB AS BIGINT) + u.UploadMB) / 1024.0 AS DECIMAL(12,2)) AS TotalGB
    FROM dbo.UsageRecords AS u
    JOIN dbo.Subscriptions AS s ON s.SubscriptionID = u.SubscriptionID
    JOIN dbo.Customers     AS c ON c.CustomerID     = s.CustomerID
    JOIN dbo.Plans         AS p ON p.PlanID         = s.PlanID
    -- a date RANGE (not YEAR(UsageDate) = ...) so an index on UsageDate can seek
    WHERE u.UsageDate >= @PeriodStart
      AND u.UsageDate <= @PeriodEnd
    GROUP BY u.SubscriptionID, c.FullName, p.PlanName, p.QuotaGB
    ORDER BY TotalGB DESC;
END;
GO

-- Store the usage of one subscription for one day.
CREATE OR ALTER PROCEDURE dbo.usp_AddUsage
    @SubscriptionID INT,
    @UsageDate      DATE,
    @DownloadMB     INT,
    @UploadMB       INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Subscriptions
                   WHERE SubscriptionID = @SubscriptionID AND Status = 'Active')
        THROW 50050, 'Usage can only be recorded for an active subscription.', 1;

    IF @UsageDate > CAST(GETDATE() AS DATE)
        THROW 50051, 'The usage date cannot be in the future.', 1;

    -- Negative values are refused by the CHECK constraints.
    -- A second row for the same day is refused by the unique index
    -- UX_UsageRecords_Subscription_Date (created in 07_performance.sql).
    INSERT INTO dbo.UsageRecords (SubscriptionID, UsageDate, DownloadMB, UploadMB)
    VALUES (@SubscriptionID, @UsageDate, @DownloadMB, @UploadMB);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS UsageID;
END;
GO
