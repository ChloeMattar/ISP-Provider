/* =====================================================================
   07_performance.sql : indexes on the large table, before / after

   HOW TO USE THIS SCRIPT (for the report screenshots)
   1. In SSMS press Ctrl+M  ("Include Actual Execution Plan").
   2. Run ONE numbered block at a time: select it, press F5.
   3. After each query look at:
        - the "Execution plan" tab : Scan or Seek?
        - the "Messages" tab       : "logical reads" (pages read) and elapsed time
      and note the numbers in the table of the README / report.

   Vocabulary
     Scan = SQL Server reads the whole table or index (all ~720,000 rows).
     Seek = SQL Server jumps directly to the rows it needs, like using
            the alphabetical index of a book.
     logical reads = number of 8 KB pages read. Fewer = faster.
   ===================================================================== */
USE ISPManagement;
GO
SET STATISTICS IO ON;      -- show pages read
SET STATISTICS TIME ON;    -- show CPU and elapsed time
GO

/* =====================================================================
   KEY QUERY 1 : daily usage of one subscription for one month
   (what usp_GetDailyUsage and fn_MonthlyUsageGB do)
   ===================================================================== */

-- [1] BEFORE. The table is only ordered by UsageID, so SQL Server has to
--     read every row to find the 31 it needs: Clustered Index SCAN.
SELECT UsageDate, DownloadMB, UploadMB
FROM dbo.UsageRecords
WHERE SubscriptionID = 509
  AND UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31';
GO

-- [2] THE INDEX.
--     Key (SubscriptionID, UsageDate): rows are sorted by subscription, then
--       by date, exactly how the query filters.
--     INCLUDE (DownloadMB, UploadMB): the two other columns the query returns
--       are stored in the index too, so SQL Server never goes back to the
--       table ("covering index").
--     UNIQUE: also enforces the rule "one usage row per subscription per day".
CREATE UNIQUE NONCLUSTERED INDEX UX_UsageRecords_Subscription_Date
    ON dbo.UsageRecords (SubscriptionID, UsageDate)
    INCLUDE (DownloadMB, UploadMB);
GO

-- [3] AFTER. Same query: Index SEEK, a handful of pages.
SELECT UsageDate, DownloadMB, UploadMB
FROM dbo.UsageRecords
WHERE SubscriptionID = 509
  AND UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31';
GO

/* =====================================================================
   KEY QUERY 2 : total usage per subscription for one month
   (what usp_GetTopConsumers and usp_GenerateMonthlyInvoices do)
   ===================================================================== */

-- [4] BEFORE. The filter is on the date only. The index of block [2] starts
--     with SubscriptionID, so it cannot jump to a date: SQL Server SCANS
--     all 12 months to keep 1.
SELECT TOP (10) SubscriptionID,
       SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31'
GROUP BY SubscriptionID
ORDER BY TotalGB DESC;
GO

-- [5] THE INDEX. Sorted by date, so one month is one continuous block.
CREATE NONCLUSTERED INDEX IX_UsageRecords_Date
    ON dbo.UsageRecords (UsageDate)
    INCLUDE (SubscriptionID, DownloadMB, UploadMB);
GO

-- [6] AFTER. Index SEEK on the month: about 1/12 of the pages.
SELECT TOP (10) SubscriptionID,
       SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31'
GROUP BY SubscriptionID
ORDER BY TotalGB DESC;
GO

/* =====================================================================
   KEY QUERY 3 : same result, two ways of writing the filter
   Shows that a good index is useless if the query hides the column
   inside a function.
   ===================================================================== */

-- [7] BAD. YEAR() and MONTH() must be computed for every row before
--     comparing, so the index order cannot be used: Index SCAN.
SELECT SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE YEAR(UsageDate) = 2026
  AND MONTH(UsageDate) = 3;
GO

-- [8] GOOD. The column is compared directly to a range: Index SEEK.
--     This is why every procedure uses @PeriodStart / @PeriodEnd.
SELECT SUM(CAST(DownloadMB AS BIGINT) + UploadMB) / 1024.0 AS TotalGB
FROM dbo.UsageRecords
WHERE UsageDate >= '2026-03-01'
  AND UsageDate <= '2026-03-31';
GO

/* =====================================================================
   Small supporting indexes (not on the large table)
   SQL Server does not index foreign key columns by itself.
     - usp_GetPayments filters Payments by InvoiceID
     - fn_CustomerBalance and usp_GetSubscriptions filter Subscriptions by CustomerID
   ===================================================================== */
CREATE NONCLUSTERED INDEX IX_Payments_InvoiceID
    ON dbo.Payments (InvoiceID);
GO
CREATE NONCLUSTERED INDEX IX_Subscriptions_CustomerID
    ON dbo.Subscriptions (CustomerID);
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
