-- ISP Management System - tests.
--
-- Run the whole script (F5) and look at the Messages tab: each test prints
-- PASS or FAIL. Test 7 shows its result in the Results tab instead.
-- Tests 1-9 don't leave any changes behind.
-- Test 10 (two users at once) is done by hand, see the bottom of the file.

USE ISPManagement;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Test 1: a negative price is rejected by the CHECK constraint
BEGIN TRY
    INSERT INTO dbo.Plans (PlanName, SpeedMbps, QuotaGB, MonthlyPrice, OveragePricePerGB)
    VALUES ('Bad plan', 10, 100, -5, 0.5);
    PRINT 'TEST 1 FAIL: a negative price was accepted';
END TRY
BEGIN CATCH
    PRINT 'TEST 1 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Test 2: a duplicate phone is rejected by the UNIQUE constraint
BEGIN TRY
    DECLARE @Phone VARCHAR(20) = (SELECT TOP (1) Phone FROM dbo.Customers);
    EXEC dbo.usp_AddCustomer @FullName = N'Copy Cat', @Phone = @Phone, @City = N'Beirut';
    PRINT 'TEST 2 FAIL: a duplicate phone was accepted';
END TRY
BEGIN CATCH
    PRINT 'TEST 2 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Test 3: a customer with subscriptions can't be deleted (foreign key)
BEGIN TRY
    DELETE FROM dbo.Customers WHERE CustomerID = 1;
    PRINT 'TEST 3 FAIL: a customer with subscriptions was deleted';
END TRY
BEGIN CATCH
    PRINT 'TEST 3 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Test 4: a customer can't have two active subscriptions
BEGIN TRY
    DECLARE @Customer INT = (SELECT TOP (1) CustomerID FROM dbo.Subscriptions WHERE Status = 'Active');
    EXEC dbo.usp_ActivateSubscription @CustomerID = @Customer, @PlanID = 1;
    PRINT 'TEST 4 FAIL: a second open subscription was created';
END TRY
BEGIN CATCH
    PRINT 'TEST 4 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Test 5: paying more than the balance is refused, and no payment row is left behind
DECLARE @Invoice INT = (SELECT TOP (1) InvoiceID FROM dbo.Invoices WHERE Status = 'Unpaid');
DECLARE @PaymentsBefore INT = (SELECT COUNT(*) FROM dbo.Payments WHERE InvoiceID = @Invoice);
BEGIN TRY
    EXEC dbo.usp_RecordPayment @InvoiceID = @Invoice, @Amount = 99999, @Method = 'Cash';
    PRINT 'TEST 5 FAIL: an overpayment was accepted';
END TRY
BEGIN CATCH
    IF (SELECT COUNT(*) FROM dbo.Payments WHERE InvoiceID = @Invoice) = @PaymentsBefore
        PRINT 'TEST 5 PASS: ' + ERROR_MESSAGE() + ' (no payment row was left)';
    ELSE
        PRINT 'TEST 5 FAIL: the payment row was not rolled back';
END CATCH;
GO

-- Test 6: paying the full balance marks the invoice as Paid (undone afterwards)
DECLARE @Invoice INT, @Balance DECIMAL(10,2);
SELECT TOP (1) @Invoice = InvoiceID, @Balance = Amount - AmountPaid
FROM dbo.Invoices WHERE Status = 'Unpaid';

BEGIN TRANSACTION;                 -- only here so the test can be rolled back
    EXEC dbo.usp_RecordPayment @InvoiceID = @Invoice, @Amount = @Balance, @Method = 'Card';
    IF (SELECT Status FROM dbo.Invoices WHERE InvoiceID = @Invoice) = 'Paid'
        PRINT 'TEST 6 PASS: invoice is Paid after paying the full balance';
    ELSE
        PRINT 'TEST 6 FAIL: invoice status was not updated';
ROLLBACK TRANSACTION;
GO

-- Test 7: billing a month twice creates nothing the second time.
-- September 2026 is already billed, so the Results tab should show InvoicesCreated = 0.
EXEC dbo.usp_GenerateMonthlyInvoices @Year = 2026, @Month = 9;
GO

-- Test 8: the audit trigger logs a status change (undone afterwards)
DECLARE @Sub INT = (SELECT TOP (1) SubscriptionID FROM dbo.Subscriptions WHERE Status = 'Active');
DECLARE @AuditBefore INT = (SELECT COUNT(*) FROM dbo.SubscriptionAudit);

BEGIN TRANSACTION;
    EXEC dbo.usp_CancelSubscription @SubscriptionID = @Sub;
    IF (SELECT COUNT(*) FROM dbo.SubscriptionAudit) = @AuditBefore + 1
        PRINT 'TEST 8 PASS: the trigger wrote one audit row';
    ELSE
        PRINT 'TEST 8 FAIL: no audit row';
ROLLBACK TRANSACTION;
GO

-- Test 9: payments can't be deleted
BEGIN TRY
    DELETE FROM dbo.Payments WHERE PaymentID = 1;
    PRINT 'TEST 9 FAIL: a payment was deleted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'TEST 9 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Security test: what the app's login can and can't do.
-- EXECUTE AS USER runs the next statements as isp_app; REVERT switches back.
EXECUTE AS USER = 'isp_app';
BEGIN TRY
    SELECT TOP (1) * FROM dbo.Customers;
    PRINT 'SECURITY FAIL: isp_app can read a table directly';
END TRY
BEGIN CATCH
    PRINT 'SECURITY PASS (direct SELECT refused): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_GetPlans;
    PRINT 'SECURITY PASS: isp_app can execute a procedure';
END TRY
BEGIN CATCH
    PRINT 'SECURITY FAIL: ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

/*
Test 10: two users at the same time (by hand, in two SSMS windows)

Two cashiers try to pay the same invoice in full at the same moment.
Only one payment should go through.

0. Pick an unpaid invoice and note its ID and balance:
     SELECT TOP (1) InvoiceID, Amount - AmountPaid AS Balance
     FROM dbo.Invoices WHERE Status = 'Unpaid';

1. Window A (cashier 1 starts paying but doesn't finish yet):
     BEGIN TRANSACTION;
     EXEC dbo.usp_RecordPayment @InvoiceID = <ID>, @Amount = <Balance>, @Method = 'Cash';
     -- don't commit yet

2. Window B (cashier 2 pays the same invoice):
     EXEC dbo.usp_RecordPayment @InvoiceID = <ID>, @Amount = <Balance>, @Method = 'Card';
   Window B just sits on "Executing query..." - it's waiting on the UPDLOCK
   line because window A is holding the invoice row.

3. Window A:
     COMMIT TRANSACTION;

4. Window B continues right away, reads the new balance (0) and says
   "The payment is larger than the remaining balance."
   Only one payment row exists; the invoice wasn't paid twice.

If you ROLLBACK in step 3 instead, cashier 1's payment is undone and
window B's payment goes through.

Without UPDLOCK, both windows would read the old balance and both would
insert a payment. The second UPDATE would then hit CK_Invoices_AmountPaid
and be rolled back, so the data would still be correct, but the user would
get a technical error instead of a clear message. With UPDLOCK the second
cashier just waits their turn.
*/
