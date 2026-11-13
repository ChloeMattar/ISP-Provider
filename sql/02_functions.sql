/* =====================================================================
   02_functions.sql : scalar functions (business calculations)
   ===================================================================== */
USE ISPManagement;
GO

/* ---------------------------------------------------------------------
   fn_OverageCharge
   Money to add to an invoice when the customer used more than the quota.
   Example: quota 100 GB, used 112.5 GB, price 0.50/GB  ->  12.5 * 0.50 = 6.25
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_OverageCharge
(
    @TotalMB    BIGINT,          -- usage of the month in megabytes
    @QuotaGB    INT,             -- allowance of the plan
    @PricePerGB DECIMAL(10,2)    -- overage price of the plan
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    -- 1024.0 (with the .0) forces a decimal division, not an integer one
    DECLARE @OverGB DECIMAL(12,2) = (@TotalMB / 1024.0) - @QuotaGB;

    IF @OverGB <= 0
        RETURN 0;                -- under the quota: nothing extra

    RETURN ROUND(@OverGB * @PricePerGB, 2);
END;
GO

/* ---------------------------------------------------------------------
   fn_MonthlyUsageGB
   Total GB (download + upload) of one subscription in one month.
   Reads the large table.
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_MonthlyUsageGB
(
    @SubscriptionID INT,
    @Year           INT,
    @Month          INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @PeriodStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @PeriodEnd   DATE = EOMONTH(@PeriodStart);    -- last day of that month
    DECLARE @TotalMB     BIGINT;

    -- CAST to BIGINT so a big sum can never overflow an INT
    SELECT @TotalMB = SUM(CAST(DownloadMB AS BIGINT) + UploadMB)
    FROM dbo.UsageRecords
    WHERE SubscriptionID = @SubscriptionID
      AND UsageDate >= @PeriodStart
      AND UsageDate <= @PeriodEnd;

    -- ISNULL: no usage rows gives NULL, we return 0 instead
    RETURN ISNULL(@TotalMB, 0) / 1024.0;
END;
GO

/* ---------------------------------------------------------------------
   fn_CustomerBalance
   What a customer still owes: sum of (Amount - AmountPaid) on all invoices.
   --------------------------------------------------------------------- */
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
