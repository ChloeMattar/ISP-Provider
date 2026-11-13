/* =====================================================================
   05_insert_data.sql : test data
     6 plans, 2,000 customers, 2,000 subscriptions,
     ~720,000 usage rows (one per subscription per day, 12 months),
     ~21,700 invoices and their payments.

   Everything is SET-BASED: one INSERT ... SELECT builds thousands of rows.
   No row-by-row loop, so the whole script runs in well under a minute.
   Run on a fresh database (after scripts 01 to 04).
   ===================================================================== */
USE ISPManagement;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1. Plans (PlanID 1 to 6, in this order)
   --------------------------------------------------------------------- */
INSERT INTO dbo.Plans (PlanName, SpeedMbps, QuotaGB, MonthlyPrice, OveragePricePerGB)
VALUES ('Home 10',       10,  100,  20.00, 0.50),
       ('Home 30',       30,  200,  30.00, 0.40),
       ('Home 50',       50,  300,  40.00, 0.30),
       ('Fiber 100',    100,  500,  60.00, 0.25),
       ('Fiber 300',    300, 1000,  90.00, 0.20),
       ('Business 500', 500, 2000, 150.00, 0.15);
GO

/* ---------------------------------------------------------------------
   2. Customers : 40 first names x 50 last names = 2,000 different people
   CROSS JOIN = every first name combined with every last name.
   ROW_NUMBER() gives each person a number n (1..2000) in random order;
   we build a unique phone and email from n.
   --------------------------------------------------------------------- */
WITH FirstNames AS (
    SELECT FirstName
    FROM (VALUES ('Georges'),('Elie'),('Charbel'),('Joseph'),('Tony'),('Michel'),('Pierre'),('Antoine'),
                 ('Fadi'),('Rami'),('Karim'),('Ziad'),('Walid'),('Nabil'),('Samir'),('Hadi'),
                 ('Marc'),('Jad'),('Ali'),('Hassan'),('Omar'),('Khalil'),('Maroun'),('Rita'),
                 ('Maria'),('Nour'),('Lea'),('Sara'),('Maya'),('Rima'),('Layal'),('Nadine'),
                 ('Carla'),('Joelle'),('Mira'),('Lara'),('Hiba'),('Dana'),('Yara'),('Tala')
         ) AS f (FirstName)
),
LastNames AS (
    SELECT LastName
    FROM (VALUES ('Khoury'),('Haddad'),('Saliba'),('Nassar'),('Karam'),('Sleiman'),('Harb'),('Abboud'),
                 ('Nakhle'),('Atallah'),('Rahme'),('Daher'),('Azar'),('Matar'),('Najjar'),('Tannous'),
                 ('Sfeir'),('Hayek'),('Maalouf'),('Chidiac'),('Barakat'),('Younes'),('Mansour'),('Saade'),
                 ('Zgheib'),('Awad'),('Fares'),('Hanna'),('Issa'),('Moussa'),('Ibrahim'),('Yazbeck'),
                 ('Kanaan'),('Farhat'),('Hamdan'),('Jaber'),('Hijazi'),('Baydoun'),('Itani'),('Sinno'),
                 ('Kabbani'),('Tabbara'),('Kassis'),('Chahine'),('Habib'),('Ghanem'),('Rizk'),('Saab'),
                 ('Tohme'),('Zein')
         ) AS l (LastName)
),
Numbered AS (
    SELECT f.FirstName, l.LastName,
           ROW_NUMBER() OVER (ORDER BY NEWID()) AS n      -- NEWID() = random order
    FROM FirstNames AS f
    CROSS JOIN LastNames AS l
)
INSERT INTO dbo.Customers (FullName, Phone, Email, City)
SELECT FirstName + ' ' + LastName,
       '70' + CAST(100000 + n AS VARCHAR(6)),                                     -- 70100001, 70100002...
       LOWER(FirstName + '.' + LastName) + CAST(n AS VARCHAR(4)) + '@example.com',
       -- n % 8 is 0..7 ; CHOOSE picks the city at that position
       CHOOSE(n % 8 + 1, 'Beirut', 'Jounieh', 'Tripoli', 'Saida', 'Zahle', 'Byblos', 'Tyre', 'Baabda')
FROM Numbered;
GO

/* ---------------------------------------------------------------------
   3. Subscriptions : one per customer
   % is the remainder of a division; we use it to spread customers:
     plan   : 30% Home 10, 30% Home 30, 20% Home 50, 10% Fiber 100, 5% + 5% the big ones
     status : 1 in 25 cancelled (on 30 June 2026), 1 in 25 suspended, the rest active
     start  : spread over the first 300 days of 2025
   --------------------------------------------------------------------- */
INSERT INTO dbo.Subscriptions (CustomerID, PlanID, StartDate, EndDate, Status)
SELECT c.CustomerID,
       CASE WHEN c.CustomerID % 20 < 6  THEN 1
            WHEN c.CustomerID % 20 < 12 THEN 2
            WHEN c.CustomerID % 20 < 16 THEN 3
            WHEN c.CustomerID % 20 < 18 THEN 4
            WHEN c.CustomerID % 20 = 18 THEN 5
            ELSE 6 END,
       DATEADD(DAY, c.CustomerID % 300, CAST('2025-01-01' AS DATE)),
       CASE WHEN c.CustomerID % 25 = 0 THEN '2026-06-30' END,     -- no ELSE = NULL
       CASE WHEN c.CustomerID % 25 = 0 THEN 'Cancelled'
            WHEN c.CustomerID % 25 = 1 THEN 'Suspended'
            ELSE 'Active' END
FROM dbo.Customers AS c;
GO

/* ---------------------------------------------------------------------
   4. UsageRecords : THE LARGE TABLE
   Calendar = the 365 days from 2025-11-01 to 2026-10-31.
   (sys.all_objects is only used as "a table with more than 365 rows"
    so that ROW_NUMBER can count 0, 1, 2 ... 364.)
   Subscriptions x Calendar = one row per subscription per day.

   Making the numbers meaningful:
     - average per day = quota of the plan / 30 days
     - each subscription has its own habit: (2 + SubscriptionID % 10) / 10
       = 0.2 .. 1.1 of the quota, so some customers go over quota every month
     - each day is random between 50% and 150% of that habit
     - upload is about one tenth of the quota pace
   --------------------------------------------------------------------- */
WITH Calendar AS (
    SELECT TOP (365)
           DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, CAST('2025-11-01' AS DATE)) AS UsageDate
    FROM sys.all_objects
)
INSERT INTO dbo.UsageRecords (SubscriptionID, UsageDate, DownloadMB, UploadMB)
SELECT s.SubscriptionID,
       d.UsageDate,
       CAST(p.QuotaGB * 1024.0 / 30
            * ((2 + s.SubscriptionID % 10) / 10.0)
            * (0.5 + (ABS(CHECKSUM(NEWID())) % 1000) / 1000.0) AS INT),
       CAST(p.QuotaGB * 1024.0 / 30
            * 0.1
            * (0.5 + (ABS(CHECKSUM(NEWID())) % 1000) / 1000.0) AS INT)
FROM dbo.Subscriptions AS s
JOIN dbo.Plans AS p ON p.PlanID = s.PlanID
CROSS JOIN Calendar AS d
WHERE d.UsageDate >= s.StartDate
  AND (s.EndDate IS NULL OR d.UsageDate <= s.EndDate);     -- no usage after cancellation
GO

/* ---------------------------------------------------------------------
   5. Invoices : we do not invent them, we call our own procedure once per
   month from November 2025 to September 2026.
   October 2026 is left unbilled on purpose: it is billed live in the demo.
   --------------------------------------------------------------------- */
DECLARE @MonthStart DATE = '2025-11-01';
DECLARE @y INT, @m INT;

WHILE @MonthStart <= '2026-09-01'
BEGIN
    SET @y = YEAR(@MonthStart);
    SET @m = MONTH(@MonthStart);

    EXEC dbo.usp_GenerateMonthlyInvoices @Year = @y, @Month = @m;

    SET @MonthStart = DATEADD(MONTH, 1, @MonthStart);
END;
GO

/* ---------------------------------------------------------------------
   6. Payments : history
     - every invoice up to August 2026 is fully paid
     - September 2026: 4 subscriptions out of 5 paid in full,
                       1 in 10 paid half (Partial), 1 in 10 paid nothing (Unpaid)
   Payment + invoice update go together, so we use a transaction here too.
   --------------------------------------------------------------------- */
BEGIN TRANSACTION;

    -- full payments
    INSERT INTO dbo.Payments (InvoiceID, Amount, Method, PaidAt)
    SELECT InvoiceID,
           Amount,
           CHOOSE(InvoiceID % 3 + 1, 'Cash', 'Card', 'Transfer'),
           DATEADD(DAY, 1 + InvoiceID % 9, PeriodEnd)          -- paid 1 to 9 days after month end
    FROM dbo.Invoices
    WHERE PeriodStart < '2026-09-01'
       OR SubscriptionID % 5 <> 0;

    UPDATE dbo.Invoices
    SET AmountPaid = Amount,
        Status     = 'Paid'
    WHERE PeriodStart < '2026-09-01'
       OR SubscriptionID % 5 <> 0;

    -- half payments on some September invoices
    INSERT INTO dbo.Payments (InvoiceID, Amount, Method, PaidAt)
    SELECT InvoiceID, ROUND(Amount / 2, 2), 'Cash', DATEADD(DAY, 5, PeriodEnd)
    FROM dbo.Invoices
    WHERE PeriodStart = '2026-09-01'
      AND SubscriptionID % 10 = 0;

    UPDATE dbo.Invoices
    SET AmountPaid = ROUND(Amount / 2, 2),
        Status     = 'Partial'
    WHERE PeriodStart = '2026-09-01'
      AND SubscriptionID % 10 = 0;

COMMIT TRANSACTION;
GO

/* ---------------------------------------------------------------------
   7. Check : how many rows in each table
   --------------------------------------------------------------------- */
SELECT 'Customers'     AS TableName, COUNT(*) AS NumberOfRows FROM dbo.Customers
UNION ALL SELECT 'Plans',         COUNT(*) FROM dbo.Plans
UNION ALL SELECT 'Subscriptions', COUNT(*) FROM dbo.Subscriptions
UNION ALL SELECT 'UsageRecords',  COUNT(*) FROM dbo.UsageRecords
UNION ALL SELECT 'Invoices',      COUNT(*) FROM dbo.Invoices
UNION ALL SELECT 'Payments',      COUNT(*) FROM dbo.Payments;
GO
