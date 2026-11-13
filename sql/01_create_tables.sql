/* =====================================================================
   GIN401 Lab Project - ISP Management System
   01_create_tables.sql : database, tables, keys, constraints
   Run once in SSMS, top to bottom.
   ===================================================================== */

CREATE DATABASE ISPManagement;
GO
USE ISPManagement;
GO

/* ---------------------------------------------------------------------
   1. Customers : the people we bill
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Customers
(
    CustomerID INT IDENTITY(1,1) NOT NULL,   -- SQL Server generates 1, 2, 3...
    FullName   NVARCHAR(100)     NOT NULL,   -- NVARCHAR: accepts Arabic/accents
    Phone      VARCHAR(20)       NOT NULL,
    Email      VARCHAR(100)      NULL,       -- optional
    City       NVARCHAR(50)      NOT NULL,
    Status     VARCHAR(10)       NOT NULL
        CONSTRAINT DF_Customers_Status DEFAULT 'Active',
    CreatedAt  DATETIME2(0)      NOT NULL
        CONSTRAINT DF_Customers_CreatedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Customers        PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_Customers_Phone  UNIQUE (Phone),   -- no two customers share a phone
    CONSTRAINT CK_Customers_Status CHECK (Status IN ('Active', 'Inactive'))
);
GO

/* ---------------------------------------------------------------------
   2. Plans : the internet packages we sell
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Plans
(
    PlanID            INT IDENTITY(1,1) NOT NULL,
    PlanName          NVARCHAR(50)      NOT NULL,
    SpeedMbps         INT               NOT NULL,
    QuotaGB           INT               NOT NULL,   -- monthly allowance
    MonthlyPrice      DECIMAL(10,2)     NOT NULL,   -- DECIMAL: exact, never FLOAT for money
    OveragePricePerGB DECIMAL(10,2)     NOT NULL,   -- charged for each GB above the quota
    IsActive          BIT               NOT NULL
        CONSTRAINT DF_Plans_IsActive DEFAULT 1,     -- 0 = no longer sold, but kept for history

    CONSTRAINT PK_Plans          PRIMARY KEY (PlanID),
    CONSTRAINT UQ_Plans_PlanName UNIQUE (PlanName),
    CONSTRAINT CK_Plans_Speed    CHECK (SpeedMbps > 0),
    CONSTRAINT CK_Plans_Quota    CHECK (QuotaGB > 0),
    CONSTRAINT CK_Plans_Price    CHECK (MonthlyPrice > 0),
    CONSTRAINT CK_Plans_Overage  CHECK (OveragePricePerGB >= 0)
);
GO

/* ---------------------------------------------------------------------
   3. Subscriptions : one customer on one plan
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Subscriptions
(
    SubscriptionID INT IDENTITY(1,1) NOT NULL,
    CustomerID     INT               NOT NULL,
    PlanID         INT               NOT NULL,
    StartDate      DATE              NOT NULL,
    EndDate        DATE              NULL,       -- NULL = still running
    Status         VARCHAR(10)       NOT NULL
        CONSTRAINT DF_Subscriptions_Status DEFAULT 'Active',

    CONSTRAINT PK_Subscriptions PRIMARY KEY (SubscriptionID),
    CONSTRAINT FK_Subscriptions_Customers
        FOREIGN KEY (CustomerID) REFERENCES dbo.Customers (CustomerID),
    CONSTRAINT FK_Subscriptions_Plans
        FOREIGN KEY (PlanID) REFERENCES dbo.Plans (PlanID),
    CONSTRAINT CK_Subscriptions_Status
        CHECK (Status IN ('Active', 'Suspended', 'Cancelled')),
    CONSTRAINT CK_Subscriptions_Dates
        CHECK (EndDate IS NULL OR EndDate >= StartDate)
);
GO

-- Business rule: a customer has at most ONE open subscription.
-- A filtered unique index only looks at the rows matching the WHERE,
-- so a customer can have many Cancelled rows (history) but only one open row.
CREATE UNIQUE INDEX UX_Subscriptions_OneOpenPerCustomer
    ON dbo.Subscriptions (CustomerID)
    WHERE Status IN ('Active', 'Suspended');
GO

/* ---------------------------------------------------------------------
   4. UsageRecords : daily consumption  (THE LARGE TABLE, ~720,000 rows)
   One row = one subscription on one day.
   No index on (SubscriptionID, UsageDate) yet: we add it in the
   performance step so we can show the plan before and after.
   --------------------------------------------------------------------- */
CREATE TABLE dbo.UsageRecords
(
    UsageID        INT IDENTITY(1,1) NOT NULL,
    SubscriptionID INT               NOT NULL,
    UsageDate      DATE              NOT NULL,
    DownloadMB     INT               NOT NULL,
    UploadMB       INT               NOT NULL,

    CONSTRAINT PK_UsageRecords PRIMARY KEY (UsageID),
    CONSTRAINT FK_UsageRecords_Subscriptions
        FOREIGN KEY (SubscriptionID) REFERENCES dbo.Subscriptions (SubscriptionID),
    CONSTRAINT CK_UsageRecords_Download CHECK (DownloadMB >= 0),
    CONSTRAINT CK_UsageRecords_Upload   CHECK (UploadMB >= 0)
);
GO

/* ---------------------------------------------------------------------
   5. Invoices : one bill per subscription per month
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Invoices
(
    InvoiceID      INT IDENTITY(1,1) NOT NULL,
    SubscriptionID INT               NOT NULL,
    PeriodStart    DATE              NOT NULL,   -- first day of the billed month
    PeriodEnd      DATE              NOT NULL,   -- last day of the billed month
    Amount         DECIMAL(10,2)     NOT NULL,   -- plan price + overage
    AmountPaid     DECIMAL(10,2)     NOT NULL
        CONSTRAINT DF_Invoices_AmountPaid DEFAULT 0,
    Status         VARCHAR(10)       NOT NULL
        CONSTRAINT DF_Invoices_Status DEFAULT 'Unpaid',
    IssuedAt       DATETIME2(0)      NOT NULL
        CONSTRAINT DF_Invoices_IssuedAt DEFAULT SYSDATETIME(),
    DueDate        DATE              NOT NULL,

    CONSTRAINT PK_Invoices PRIMARY KEY (InvoiceID),
    CONSTRAINT FK_Invoices_Subscriptions
        FOREIGN KEY (SubscriptionID) REFERENCES dbo.Subscriptions (SubscriptionID),
    -- Business rule: a subscription cannot be billed twice for the same month.
    CONSTRAINT UQ_Invoices_Subscription_Period UNIQUE (SubscriptionID, PeriodStart),
    CONSTRAINT CK_Invoices_Period     CHECK (PeriodEnd > PeriodStart),
    CONSTRAINT CK_Invoices_Amount     CHECK (Amount >= 0),
    -- Business rule: we can never collect more than the invoice amount.
    CONSTRAINT CK_Invoices_AmountPaid CHECK (AmountPaid >= 0 AND AmountPaid <= Amount),
    CONSTRAINT CK_Invoices_Status     CHECK (Status IN ('Unpaid', 'Partial', 'Paid'))
);
GO

/* ---------------------------------------------------------------------
   6. Payments : money received against an invoice
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Payments
(
    PaymentID INT IDENTITY(1,1) NOT NULL,
    InvoiceID INT               NOT NULL,
    Amount    DECIMAL(10,2)     NOT NULL,
    Method    VARCHAR(10)       NOT NULL,
    PaidAt    DATETIME2(0)      NOT NULL
        CONSTRAINT DF_Payments_PaidAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Invoices
        FOREIGN KEY (InvoiceID) REFERENCES dbo.Invoices (InvoiceID),
    CONSTRAINT CK_Payments_Amount CHECK (Amount > 0),
    CONSTRAINT CK_Payments_Method CHECK (Method IN ('Cash', 'Card', 'Transfer'))
);
GO

/* ---------------------------------------------------------------------
   7. SubscriptionAudit : history of status / plan changes
   Nobody inserts here directly: a trigger on Subscriptions fills it.
   --------------------------------------------------------------------- */
CREATE TABLE dbo.SubscriptionAudit
(
    AuditID        INT IDENTITY(1,1) NOT NULL,
    SubscriptionID INT               NOT NULL,
    OldStatus      VARCHAR(10)       NOT NULL,
    NewStatus      VARCHAR(10)       NOT NULL,
    OldPlanID      INT               NOT NULL,
    NewPlanID      INT               NOT NULL,
    ChangedAt      DATETIME2(0)      NOT NULL
        CONSTRAINT DF_SubscriptionAudit_ChangedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_SubscriptionAudit PRIMARY KEY (AuditID),
    CONSTRAINT FK_SubscriptionAudit_Subscriptions
        FOREIGN KEY (SubscriptionID) REFERENCES dbo.Subscriptions (SubscriptionID)
);
GO
