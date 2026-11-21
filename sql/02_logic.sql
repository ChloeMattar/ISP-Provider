-- ISP Management System - functions, stored procedures and triggers.
--
-- A few habits used in every procedure:
--   SET NOCOUNT ON  stops the "(1 row affected)" messages.
--   THROW 5xxxx     raises our own errors; the API shows their text to the user.
--   Each procedure ends with a SELECT so the app always gets rows back.

USE ISPManagement;
GO
-- Needed because Subscriptions has a filtered index.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO


-- Functions 

-- Extra charge when a customer goes over the plan's quota.
-- e.g. quota 100 GB, used 112.5 GB at 0.50/GB -> 12.5 * 0.50 = 6.25
CREATE OR ALTER FUNCTION dbo.fn_OverageCharge
(
    @TotalMB    BIGINT,
    @QuotaGB    INT,
    @PricePerGB DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    -- 1024.0 instead of 1024, otherwise SQL Server does an integer division
    DECLARE @OverGB DECIMAL(12,2) = (@TotalMB / 1024.0) - @QuotaGB;

    IF @OverGB <= 0
        RETURN 0;

    RETURN ROUND(@OverGB * @PricePerGB, 2);
END;
GO

-- How much a customer still owes across all their invoices.
CREATE OR ALTER FUNCTION dbo.fn_CustomerBalance
(
    @CustomerID INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Balance DECIMAL(12,2);

    SELECT @Balance = SUM(i.Amount - i.AmountPaid)
    FROM dbo.Invoices AS i
    JOIN dbo.Subscriptions AS s ON s.SubscriptionID = i.SubscriptionID
    WHERE s.CustomerID = @CustomerID;

    RETURN ISNULL(@Balance, 0);
END;
GO


--  Customers 

-- Search by name (anywhere in it) or by phone (from the start).
-- No search text = list everyone.
-- CHARINDEX instead of LIKE: with LIKE, a "%" or "_" typed in the search
-- box would act as a wildcard and match everybody.
CREATE OR ALTER PROCEDURE dbo.usp_SearchCustomers
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (50)
           c.CustomerID, c.FullName, c.Phone, c.Email, c.City,
           dbo.fn_CustomerBalance(c.CustomerID) AS Balance
    FROM dbo.Customers AS c
    WHERE @Search IS NULL
       OR CHARINDEX(@Search, c.FullName) > 0
       OR CHARINDEX(@Search, c.Phone)    = 1
    ORDER BY c.FullName;
END;
GO

-- The parameters are bigger than the columns on purpose. SQL Server quietly
-- cuts a value that is longer than its parameter, so with 200-character
-- parameters a too-long value arrives whole and we can refuse it.
CREATE OR ALTER PROCEDURE dbo.usp_AddCustomer
    @FullName NVARCHAR(200),
    @Phone    VARCHAR(200),
    @Email    VARCHAR(200) = NULL,
    @City     NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    -- LTRIM and RTRIM removes space from left and right 
    IF LTRIM(RTRIM(@FullName)) = '' OR LTRIM(RTRIM(@Phone)) = '' OR LTRIM(RTRIM(@City)) = ''
        THROW 50010, 'Name, phone and city are required.', 1; --custom error number

    -- same limits as the columns of dbo.Customers
    IF LEN(@FullName) > 100 OR LEN(@Phone) > 20 OR LEN(@Email) > 100 OR LEN(@City) > 50
        THROW 50012, 'Too long. Maximum: name 100, phone 20, email 100, city 50 characters.', 1;

    -- a duplicate phone gets rejected by UQ_Customers_Phone
    INSERT INTO dbo.Customers (FullName, Phone, Email, City)
    VALUES (@FullName, @Phone, @Email, @City);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS CustomerID;   -- the new customer's ID
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpdateCustomer
    @CustomerID INT,
    @FullName   NVARCHAR(200),      
    @Phone      VARCHAR(200),
    @Email      VARCHAR(200) = NULL,
    @City       NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(@FullName)) = '' OR LTRIM(RTRIM(@Phone)) = '' OR LTRIM(RTRIM(@City)) = ''
        THROW 50010, 'Name, phone and city are required.', 1;

    IF LEN(@FullName) > 100 OR LEN(@Phone) > 20 OR LEN(@Email) > 100 OR LEN(@City) > 50
        THROW 50012, 'Too long. Maximum: name 100, phone 20, email 100, city 50 characters.', 1;

    UPDATE dbo.Customers
    SET FullName = @FullName,
        Phone    = @Phone,
        Email    = @Email,
        City     = @City
    WHERE CustomerID = @CustomerID;

    IF @@ROWCOUNT = 0
        THROW 50011, 'Customer not found.', 1;

    SELECT @CustomerID AS CustomerID;
END;
GO


--  Plans 

CREATE OR ALTER PROCEDURE dbo.usp_GetPlans
AS
BEGIN
    SET NOCOUNT ON;

    SELECT PlanID, PlanName, SpeedMbps, QuotaGB, MonthlyPrice, OveragePricePerGB, IsActive
    FROM dbo.Plans
    ORDER BY MonthlyPrice;
END;
GO


--  Subscriptions 

-- Every filter is optional: NULL means "don't filter on this".
CREATE OR ALTER PROCEDURE dbo.usp_GetSubscriptions
    @CustomerName NVARCHAR(100) = NULL,
    @Status       VARCHAR(10)   = NULL,
    @PlanID       INT           = NULL
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
    WHERE (@CustomerName IS NULL OR CHARINDEX(@CustomerName, c.FullName) > 0)
      AND (@Status       IS NULL OR s.Status = @Status)
      AND (@PlanID       IS NULL OR s.PlanID = @PlanID)
    ORDER BY s.SubscriptionID DESC;
END;
GO

-- Starts a new subscription today.
CREATE OR ALTER PROCEDURE dbo.usp_ActivateSubscription
    @CustomerID INT,
    @PlanID     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID)
        THROW 50020, 'Customer not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Plans WHERE PlanID = @PlanID AND IsActive = 1)
        THROW 50021, 'Plan not found or no longer sold.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Subscriptions
               WHERE CustomerID = @CustomerID AND Status = 'Active')
        THROW 50022, 'This customer already has an open subscription.', 1;

    -- Two users activating for the same customer at the same moment could both
    -- get past the check above. If that happens, the filtered unique index
    -- UX_Subscriptions_OneOpenPerCustomer rejects the second insert.
    INSERT INTO dbo.Subscriptions (CustomerID, PlanID, StartDate)
    VALUES (@CustomerID, @PlanID, CAST(GETDATE() AS DATE));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS SubscriptionID;
END;
GO

-- Cancels a subscription as of today. A cancelled subscription stays cancelled.
CREATE OR ALTER PROCEDURE dbo.usp_CancelSubscription
    @SubscriptionID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- The "must still be Active" check is part of the UPDATE itself.
    -- If two users cancel at the same time, the second UPDATE waits for the
    -- first one, then sees the row is already Cancelled and changes nothing.
    UPDATE dbo.Subscriptions
    SET Status  = 'Cancelled',
        EndDate = CAST(GETDATE() AS DATE)
    WHERE SubscriptionID = @SubscriptionID
      AND Status = 'Active';

    -- Nothing changed: work out why so the user gets a clear message.
    IF @@ROWCOUNT = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.Subscriptions WHERE SubscriptionID = @SubscriptionID)
            THROW 50025, 'This subscription is already cancelled.', 1;

        THROW 50024, 'Subscription not found.', 1;
    END;

    SELECT @SubscriptionID AS SubscriptionID;
END;
GO


--  Billing 

CREATE OR ALTER PROCEDURE dbo.usp_GetInvoices
    @OnlyUnpaid BIT = 1,        -- 1 = only invoices that still have money due
    @CustomerID INT = NULL      -- NULL = every customer
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

-- Bills one month: one invoice for every subscription that was open during
-- that month (plan price + overage). Either all the invoices are created or
-- none are. Running it twice for the same month is safe: already billed
-- subscriptions are skipped.
CREATE OR ALTER PROCEDURE dbo.usp_GenerateMonthlyInvoices
    @Year  INT,
    @Month INT
AS
BEGIN
    SET NOCOUNT ON;
    -- if anything goes wrong (even the app timing out), roll back everything
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
               DATEADD(DAY, 10, @PeriodEnd)          -- customer has 10 days to pay
        FROM dbo.Subscriptions AS s
        JOIN dbo.Plans AS p ON p.PlanID = s.PlanID
        -- the month's usage per subscription, read from the big table in one go
        LEFT JOIN (
            SELECT SubscriptionID,
                   SUM(CAST(DownloadMB AS BIGINT) + UploadMB) AS TotalMB
            FROM dbo.UsageRecords
            WHERE UsageDate >= @PeriodStart
              AND UsageDate <= @PeriodEnd
            GROUP BY SubscriptionID
        ) AS u ON u.SubscriptionID = s.SubscriptionID
        -- open at some point during the month
        WHERE s.StartDate <= @PeriodEnd
          AND (s.EndDate IS NULL OR s.EndDate >= @PeriodStart)
          -- and not billed for this month yet
          AND NOT EXISTS (SELECT 1
                          FROM dbo.Invoices AS i
                          WHERE i.SubscriptionID = s.SubscriptionID
                            AND i.PeriodStart    = @PeriodStart);

        SET @Created = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- e.g. someone else billed the same month at the same time and
        -- UQ_Invoices_Subscription_Period rejected our rows: undo and re-raise
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Created AS InvoicesCreated;
END;
GO

-- Records a payment: inserts the payment and updates the invoice.
-- Both steps succeed together or not at all, and two cashiers paying the
-- same invoice at the same time can't overpay it.
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

        -- UPDLOCK locks the invoice row until we commit. A second payment on
        -- the same invoice waits here, then reads the updated balance.
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
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT InvoiceID, Amount, AmountPaid, Amount - AmountPaid AS Balance, Status
    FROM dbo.Invoices
    WHERE InvoiceID = @InvoiceID;
END;
GO


--  Usage 

-- Key query 1: daily usage of one subscription between two dates.
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

-- One subscription, one month: usage totals, the plan's quota, and the
-- month's invoice if it has been billed.
CREATE OR ALTER PROCEDURE dbo.usp_GetMonthlyUsage
    @SubscriptionID INT,
    @Year           INT,
    @Month          INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Month < 1 OR @Month > 12 OR @Year < 2000 OR @Year > 2100
        THROW 50040, 'Invalid year or month.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Subscriptions WHERE SubscriptionID = @SubscriptionID)
        THROW 50024, 'Subscription not found.', 1;

    DECLARE @PeriodStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @PeriodEnd   DATE = EOMONTH(@PeriodStart);
    DECLARE @DownloadMB  BIGINT;
    DECLARE @UploadMB    BIGINT;

    SELECT @DownloadMB = SUM(CAST(DownloadMB AS BIGINT)),
           @UploadMB   = SUM(CAST(UploadMB   AS BIGINT))
    FROM dbo.UsageRecords
    WHERE SubscriptionID = @SubscriptionID
      AND UsageDate >= @PeriodStart
      AND UsageDate <= @PeriodEnd;

    -- ISNULL: a month with no usage gives NULL sums, show 0 instead.
    -- LEFT JOIN: if the month isn't billed yet we still get the row,
    -- just with NULL in the invoice columns.
    SELECT s.SubscriptionID, c.FullName, p.PlanName, p.QuotaGB,
           CAST(ISNULL(@DownloadMB, 0) / 1024.0 AS DECIMAL(12,2)) AS DownloadGB,
           CAST(ISNULL(@UploadMB, 0)   / 1024.0 AS DECIMAL(12,2)) AS UploadGB,
           CAST((ISNULL(@DownloadMB, 0) + ISNULL(@UploadMB, 0)) / 1024.0 AS DECIMAL(12,2)) AS TotalGB,
           i.Amount     AS InvoiceAmount,
           i.AmountPaid AS InvoicePaid,
           i.Status     AS InvoiceStatus
    FROM dbo.Subscriptions AS s
    JOIN dbo.Customers AS c ON c.CustomerID = s.CustomerID
    JOIN dbo.Plans     AS p ON p.PlanID     = s.PlanID
    LEFT JOIN dbo.Invoices AS i ON i.SubscriptionID = s.SubscriptionID
                               AND i.PeriodStart    = @PeriodStart
    WHERE s.SubscriptionID = @SubscriptionID;
END;
GO

-- Key query 2: total usage of every subscription between two dates,
-- heaviest users first.
CREATE OR ALTER PROCEDURE dbo.usp_GetUsageReport
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate > @ToDate
        THROW 50042, 'The start date must be before the end date.', 1;

    SELECT u.SubscriptionID, c.FullName, p.PlanName,
           COUNT(*) AS DaysCounted,
           CAST(SUM(CAST(u.DownloadMB AS BIGINT)) / 1024.0 AS DECIMAL(12,2)) AS DownloadGB,
           CAST(SUM(CAST(u.UploadMB   AS BIGINT)) / 1024.0 AS DECIMAL(12,2)) AS UploadGB,
           CAST(SUM(CAST(u.DownloadMB AS BIGINT) + u.UploadMB) / 1024.0 AS DECIMAL(12,2)) AS TotalGB
    FROM dbo.UsageRecords AS u
    JOIN dbo.Subscriptions AS s ON s.SubscriptionID = u.SubscriptionID
    JOIN dbo.Customers     AS c ON c.CustomerID     = s.CustomerID
    JOIN dbo.Plans         AS p ON p.PlanID         = s.PlanID
    -- filter on the column itself (a range), so the UsageDate index can seek
    WHERE u.UsageDate >= @FromDate
      AND u.UsageDate <= @ToDate
    GROUP BY u.SubscriptionID, c.FullName, p.PlanName
    ORDER BY TotalGB DESC;
END;
GO


--  Triggers 

-- Logs every status change on Subscriptions.
-- "deleted" holds the rows before the update, "inserted" the rows after.
-- It joins the two instead of using variables, so it still works when one
-- UPDATE changes several rows.
CREATE OR ALTER TRIGGER dbo.trg_Subscriptions_Audit
ON dbo.Subscriptions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.SubscriptionAudit (SubscriptionID, OldStatus, NewStatus)
    SELECT d.SubscriptionID, d.Status, i.Status
    FROM deleted AS d
    JOIN inserted AS i ON i.SubscriptionID = d.SubscriptionID
    WHERE d.Status <> i.Status;
END;
GO

-- Payments are financial records: once saved they can't be edited or deleted,
-- not even from SSMS. INSTEAD OF means this runs in place of the UPDATE or
-- DELETE, so the original statement never happens.
CREATE OR ALTER TRIGGER dbo.trg_Payments_Protect
ON dbo.Payments
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 50060, 'Payments cannot be modified or deleted.', 1;
END;
GO
