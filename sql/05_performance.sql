-- ISP Management System - indexes on UsageRecords, with before/after queries.


USE ISPManagement;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO


--  Key query 1: one subscription's daily usage for one month (usp_GetDailyUsage) 

-- [1] Before: the table is only sorted by UsageID, so SQL Server has to read
--     every row to find the 31 it wants (clustered index scan).
SELECT UsageDate, DownloadMB, UploadMB
FROM dbo.UsageRecords
WHERE SubscriptionID = 509
  AND UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31';
GO

-- [2] The index.
--   (SubscriptionID, UsageDate): sorted the same way the query filters.
--   INCLUDE: the other two columns are stored in the index too, so SQL Server
--            never has to go back to the table (a covering index).
--   UNIQUE:  also enforces one usage row per subscription per day.
CREATE UNIQUE NONCLUSTERED INDEX UX_UsageRecords_Subscription_Date
    ON dbo.UsageRecords (SubscriptionID, UsageDate)
    INCLUDE (DownloadMB, UploadMB);
GO

-- [3] After: same query, now an index seek on a handful of pages.
SELECT UsageDate, DownloadMB, UploadMB
FROM dbo.UsageRecords
WHERE SubscriptionID = 509
  AND UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31';
GO


--  Key query 2: total usage per subscription for one month (usp_GetUsageReport, billing) 

-- [4] Before: this one filters on the date only. The index from [2] starts
--     with SubscriptionID, so it can't help; SQL Server scans all 12 months.
SELECT TOP (10) SubscriptionID,
       SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31'
GROUP BY SubscriptionID
ORDER BY TotalGB DESC;
GO

-- [5] The index: sorted by date, so one month is one continuous block.
CREATE NONCLUSTERED INDEX IX_UsageRecords_Date
    ON dbo.UsageRecords (UsageDate)
    INCLUDE (SubscriptionID, DownloadMB, UploadMB);
GO

-- [6] After: index seek on just that month, about 1/12 of the pages.
SELECT TOP (10) SubscriptionID,
       SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31'
GROUP BY SubscriptionID
ORDER BY TotalGB DESC;
GO


--  Key query 3: the same filter written two ways 

-- [7] Bad: YEAR() and MONTH() have to be computed for every row first,
--     so the index order is useless (index scan).
SELECT SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE YEAR(UsageDate) = 2026
  AND MONTH(UsageDate) = 3;
GO

-- [8] Good: the column is compared to a range directly (index seek).
--     That's why the procedures use @PeriodStart / @PeriodEnd.
SELECT SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31';
GO


--  Two small indexes on foreign keys (SQL Server doesn't create these by itself) 
-- usp_GetPayments looks up payments by InvoiceID;
-- fn_CustomerBalance and usp_GetSubscriptions look up subscriptions by CustomerID.
CREATE NONCLUSTERED INDEX IX_Payments_InvoiceID
    ON dbo.Payments (InvoiceID);
GO
CREATE NONCLUSTERED INDEX IX_Subscriptions_CustomerID
    ON dbo.Subscriptions (CustomerID);
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
