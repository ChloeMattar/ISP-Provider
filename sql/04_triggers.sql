/* =====================================================================
   04_triggers.sql : rules that run automatically inside the database
   ===================================================================== */
USE ISPManagement;
GO

/* ---------------------------------------------------------------------
   trg_Subscriptions_Audit
   After any UPDATE on Subscriptions, keep a trace of status / plan changes.
   Inside a trigger SQL Server gives us two virtual tables:
     deleted  = the rows BEFORE the update
     inserted = the rows AFTER the update
   Written with a JOIN (not variables) so it also works when one UPDATE
   changes many rows at once.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Subscriptions_Audit
ON dbo.Subscriptions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.SubscriptionAudit (SubscriptionID, OldStatus, NewStatus, OldPlanID, NewPlanID)
    SELECT d.SubscriptionID, d.Status, i.Status, d.PlanID, i.PlanID
    FROM deleted AS d
    JOIN inserted AS i ON i.SubscriptionID = d.SubscriptionID
    WHERE d.Status <> i.Status          -- only log real changes
       OR d.PlanID <> i.PlanID;
END;
GO

/* ---------------------------------------------------------------------
   trg_Payments_Protect
   A payment is a financial record: once saved it can never be changed or
   deleted, whoever tries (even directly in SSMS).
   INSTEAD OF = our code runs in place of the UPDATE / DELETE,
   so the original statement never happens.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Payments_Protect
ON dbo.Payments
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 50060, 'Payments cannot be modified or deleted.', 1;
END;
GO
