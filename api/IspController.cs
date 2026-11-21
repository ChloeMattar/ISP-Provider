using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace IspApi;

// Every API endpoint. Each one calls a single stored procedure with typed
// parameters and returns the rows as JSON. There's no SQL and no business
// logic here - the rules live in the database.
[ApiController]
[Route("api")]
public class IspController : ControllerBase
{
    private readonly Db _db;

    public IspController(Db db)
    {
        _db = db;
    }

    // Customers 

    // GET /api/customers?search=khoury
    [HttpGet("customers")]
    public async Task<IActionResult> SearchCustomers(string? search)
    {
        // empty search box -> NULL -> the procedure returns everyone
        string? value = string.IsNullOrWhiteSpace(search) ? null : search.Trim();

        var rows = await _db.RunProcedureAsync("dbo.usp_SearchCustomers",
            Db.Param("@Search", SqlDbType.NVarChar, value));

        return Ok(rows);
    }

    // POST /api/customers
    [HttpPost("customers")]
    public async Task<IActionResult> AddCustomer(CustomerRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_AddCustomer",
            Db.Param("@FullName", SqlDbType.NVarChar, request.FullName),
            Db.Param("@Phone", SqlDbType.VarChar, request.Phone),
            Db.Param("@Email", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.Email) ? null : request.Email),
            Db.Param("@City", SqlDbType.NVarChar, request.City));

        return Ok(rows[0]);
    }

    // PUT /api/customers/5
    [HttpPut("customers/{id}")]
    public async Task<IActionResult> UpdateCustomer(int id, CustomerRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_UpdateCustomer",
            Db.Param("@CustomerID", SqlDbType.Int, id),
            Db.Param("@FullName", SqlDbType.NVarChar, request.FullName),
            Db.Param("@Phone", SqlDbType.VarChar, request.Phone),
            Db.Param("@Email", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.Email) ? null : request.Email),
            Db.Param("@City", SqlDbType.NVarChar, request.City));

        return Ok(rows[0]);
    }

    //  Plans 

    // GET /api/plans
    [HttpGet("plans")]
    public async Task<IActionResult> GetPlans()
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetPlans");
        return Ok(rows);
    }

    //  Subscriptions 

    // GET /api/subscriptions?customerName=khoury&status=Active&planId=2  (all optional)
    [HttpGet("subscriptions")]
    public async Task<IActionResult> GetSubscriptions(string? customerName, string? status, int? planId)
    {
        // an empty filter is sent as NULL, which the procedure ignores
        var rows = await _db.RunProcedureAsync("dbo.usp_GetSubscriptions",
            Db.Param("@CustomerName", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(customerName) ? null : customerName.Trim()),
            Db.Param("@Status", SqlDbType.VarChar, string.IsNullOrWhiteSpace(status) ? null : status),
            Db.Param("@PlanID", SqlDbType.Int, planId));

        return Ok(rows);
    }

    // POST /api/subscriptions
    [HttpPost("subscriptions")]
    public async Task<IActionResult> ActivateSubscription(ActivateRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_ActivateSubscription",
            Db.Param("@CustomerID", SqlDbType.Int, request.CustomerID),
            Db.Param("@PlanID", SqlDbType.Int, request.PlanID));

        return Ok(rows[0]);
    }

    // PUT /api/subscriptions/7/cancel
    [HttpPut("subscriptions/{id}/cancel")]
    public async Task<IActionResult> CancelSubscription(int id)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_CancelSubscription",
            Db.Param("@SubscriptionID", SqlDbType.Int, id));

        return Ok(rows[0]);
    }

    //  Billing 

    // GET /api/invoices?onlyUnpaid=true&customerId=12
    [HttpGet("invoices")]
    public async Task<IActionResult> GetInvoices(bool onlyUnpaid = true, int? customerId = null)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetInvoices",
            Db.Param("@OnlyUnpaid", SqlDbType.Bit, onlyUnpaid),
            Db.Param("@CustomerID", SqlDbType.Int, customerId));

        return Ok(rows);
    }

    // POST /api/invoices/generate  - bills one month for every subscription
    [HttpPost("invoices/generate")]
    public async Task<IActionResult> GenerateInvoices(GenerateInvoicesRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GenerateMonthlyInvoices",
            Db.Param("@Year", SqlDbType.Int, request.Year),
            Db.Param("@Month", SqlDbType.Int, request.Month));

        return Ok(rows[0]);
    }

    // GET /api/invoices/15/payments
    [HttpGet("invoices/{id}/payments")]
    public async Task<IActionResult> GetPayments(int id)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetPayments",
            Db.Param("@InvoiceID", SqlDbType.Int, id));

        return Ok(rows);
    }

    // POST /api/invoices/15/payments
    [HttpPost("invoices/{id}/payments")]
    public async Task<IActionResult> RecordPayment(int id, PaymentRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_RecordPayment",
            Db.Param("@InvoiceID", SqlDbType.Int, id),
            Db.Param("@Amount", SqlDbType.Decimal, request.Amount),
            Db.Param("@Method", SqlDbType.VarChar, request.Method));

        return Ok(rows[0]);
    }

    // Usage 

    // GET /api/usage/monthly/509?year=2026&month=9
    [HttpGet("usage/monthly/{subscriptionId}")]
    public async Task<IActionResult> GetMonthlyUsage(int subscriptionId, int year, int month)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetMonthlyUsage",
            Db.Param("@SubscriptionID", SqlDbType.Int, subscriptionId),
            Db.Param("@Year", SqlDbType.Int, year),
            Db.Param("@Month", SqlDbType.Int, month));

        return Ok(rows);
    }

    // GET /api/usage/daily/509?from=2026-03-01&to=2026-03-31
    [HttpGet("usage/daily/{subscriptionId}")]
    public async Task<IActionResult> GetDailyUsage(int subscriptionId, DateTime from, DateTime to)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetDailyUsage",
            Db.Param("@SubscriptionID", SqlDbType.Int, subscriptionId),
            Db.Param("@FromDate", SqlDbType.Date, from),
            Db.Param("@ToDate", SqlDbType.Date, to));

        return Ok(rows);
    }

    // GET /api/usage/report?from=2026-10-01&to=2026-10-31
    [HttpGet("usage/report")]
    public async Task<IActionResult> GetUsageReport(DateTime from, DateTime to)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetUsageReport",
            Db.Param("@FromDate", SqlDbType.Date, from),
            Db.Param("@ToDate", SqlDbType.Date, to));

        return Ok(rows);
    }
}

// JSON bodies sent by the React forms. Same names as the SQL parameters.
public record CustomerRequest(string FullName, string Phone, string? Email, string City);

public record ActivateRequest(int CustomerID, int PlanID);

public record GenerateInvoicesRequest(int Year, int Month);

public record PaymentRequest(decimal Amount, string Method);
