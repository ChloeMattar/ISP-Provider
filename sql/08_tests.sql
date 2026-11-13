/* =====================================================================
   08_tests.sql : tests for the report ("Tests and their results")

   Run the whole script (F5) and read the Messages tab: each test prints
   PASS or FAIL. Tests 1 to 9 leave the data unchanged.
   Test 10 (two users at once) is done by hand, at the bottom.
   ===================================================================== */
USE ISPManagement;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---- TEST 1 : CHECK constraint refuses a negative price ------------- */
BEGIN TRY
    INSERT INTO dbo.Plans (PlanName, SpeedMbps, QuotaGB, MonthlyPrice, OveragePricePerGB)
    VALUES ('Bad plan', 10, 100, -5, 0.5);
    PRINT 'TEST 1 FAIL: a negative price was accepted';
END TRY
BEGIN CATCH
    PRINT 'TEST 1 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---- TEST 2 : UNIQUE constraint refuses a duplicate phone ----------- */
BEGIN TRY
    DECLARE @Phone VARCHAR(20) = (SELECT TOP (1) Phone FROM dbo.Customers);
    EXEC dbo.usp_AddCustomer @FullName = N'Copy Cat', @Phone = @Phone, @City = N'Beirut';
    PRINT 'TEST 2 FAIL: a duplicate phone was accepted';
END TRY
BEGIN CATCH
    PRINT 'TEST 2 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---- TEST 3 : FOREIGN KEY refuses deleting a customer with history -- */
BEGIN TRY
    DELETE FROM dbo.Customers WHERE CustomerID = 1;
    PRINT 'TEST 3 FAIL: a customer with subscriptions was deleted';
END TRY
BEGIN CATCH
    PRINT 'TEST 3 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---- TEST 4 : one open subscription per customer -------------------- */
BEGIN TRY
    DECLARE @Customer INT = (SELECT TOP (1) CustomerID FROM dbo.Subscriptions WHERE Status = 'Active');
    EXEC dbo.usp_ActivateSubscription @CustomerID = @Customer, @PlanID = 1;
    PRINT 'TEST 4 FAIL: a second open subscription was created';
END TRY
BEGIN CATCH
    PRINT 'TEST 4 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---- TEST 5 : a payment larger than the balance is refused,
                 and the transaction leaves nothing behind -------------- */
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

/* ---- TEST 6 : a correct payment updates the invoice (then undone) --- */
DECLARE @Invoice INT, @Balance DECIMAL(10,2);
SELECT TOP (1) @Invoice = InvoiceID, @Balance = Amount - AmountPaid
FROM dbo.Invoices WHERE Status = 'Unpaid';

BEGIN TRANSACTION;                 -- outer transaction, only so we can undo the test
    EXEC dbo.usp_RecordPayment @InvoiceID = @Invoice, @Amount = @Balance, @Method = 'Card';
    IF (SELECT Status FROM dbo.Invoices WHERE InvoiceID = @Invoice) = 'Paid'
        PRINT 'TEST 6 PASS: invoice is Paid after paying the full balance';
    ELSE
        PRINT 'TEST 6 FAIL: invoice status was not updated';
ROLLBACK TRANSACTION;              -- put the invoice back as it was
GO

/* ---- TEST 7 : billing the same month twice creates nothing ---------- */
DECLARE @Result TABLE (InvoicesCreated INT);
INSERT INTO @Result EXEC dbo.usp_GenerateMonthlyInvoices @Year = 2026, @Month = 9;
IF (SELECT InvoicesCreated FROM @Result) = 0
    PRINT 'TEST 7 PASS: September 2026 was already billed, 0 invoices created';
ELSE
    PRINT 'TEST 7 FAIL: duplicate invoices were created';
GO

/* ---- TEST 8 : the audit trigger logs a status change (then undone) -- */
DECLARE @Sub INT = (SELECT TOP (1) SubscriptionID FROM dbo.Subscriptions WHERE Status = 'Active');
DECLARE @AuditBefore INT = (SELECT COUNT(*) FROM dbo.SubscriptionAudit);

BEGIN TRANSACTION;
    EXEC dbo.usp_SetSubscriptionStatus @SubscriptionID = @Sub, @NewStatus = 'Suspended';
    IF (SELECT COUNT(*) FROM dbo.SubscriptionAudit) = @AuditBefore + 1
        PRINT 'TEST 8 PASS: the trigger wrote one audit row';
    ELSE
        PRINT 'TEST 8 FAIL: no audit row';
ROLLBACK TRANSACTION;
GO

/* ---- TEST 9 : payments cannot be deleted --------------------------- */
BEGIN TRY
    DELETE FROM dbo.Payments WHERE PaymentID = 1;
    PRINT 'TEST 9 FAIL: a payment was deleted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'TEST 9 PASS: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---- SECURITY TEST : what the application login can and cannot do ---
   EXECUTE AS USER = "pretend I am isp_app".  REVERT = back to myself.  */
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

/* =====================================================================
   TEST 10 : TWO USERS AT THE SAME TIME (by hand, two SSMS windows)

   Goal: two cashiers pay the SAME invoice in full at the same moment.
   Only one payment may be accepted.

   0. Pick an unpaid invoice and note its ID and balance:
        SELECT TOP (1) InvoiceID, Amount - AmountPaid AS Balance
        FROM dbo.Invoices WHERE Status = 'Unpaid';

   1. WINDOW A  (cashier 1 starts paying, but is not finished yet)
        BEGIN TRANSACTION;
        EXEC dbo.usp_RecordPayment @InvoiceID = <ID>, @Amount = <Balance>, @Method = 'Cash';
        -- do NOT commit yet

   2. WINDOW B  (cashier 2 pays the same invoice)
        EXEC dbo.usp_RecordPayment @InvoiceID = <ID>, @Amount = <Balance>, @Method = 'Card';
      -> Window B does not answer: it shows "Executing query...".
         It is WAITING on the UPDLOCK line, because window A holds the invoice row.

   3. WINDOW A
        COMMIT TRANSACTION;

   4. WINDOW B wakes up immediately, reads the NEW balance (0) and answers:
        "The payment is larger than the remaining balance."
      One payment row only. The invoice was not paid twice.

   Variant: in step 3 run ROLLBACK TRANSACTION instead of COMMIT.
   Cashier 1's payment is undone, and window B's payment is then accepted.

   What would happen without UPDLOCK?
   Both windows would read the old balance and both would insert a payment.
   The second UPDATE would then be stopped by the CHECK constraint
   CK_Invoices_AmountPaid and rolled back. The data would still be correct
   (the constraint is the safety net), but the user would get a technical
   error instead of a clear message. With UPDLOCK the second user simply
   waits for its turn.
   ===================================================================== */
